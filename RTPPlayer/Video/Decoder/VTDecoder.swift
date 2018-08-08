//
//  VTDecoder.swift
//  VideoStream
//
//  Created by Ondřej Šebelík on 03.08.18.
//  Copyright © 2018 O2 Czech Republic. All rights reserved.
//

import Foundation
import VideoToolbox

class VTDecoder: Decoder {
    
    private var formatDescription: CMFormatDescription? = nil
    
    // Basic constants
    let AVC_PREFIX_SIZE = 4
    
    // Buffers to hold the data temporarily
    private var vclBuffer: CMBlockBuffer? = nil
    private var vpsBuffer: [UInt8]? = nil
    private var spsBuffer: [UInt8]? = nil
    private var ppsBuffer: [UInt8]? = nil
    
    // Flags that control video decoding workflow
    private var hasPPS: Bool = false
    private var hasSPS: Bool = false
    private var hasVPS: Bool = false
    private var hasISlice: Bool = false
    private var hasTimeSync: Bool = false
    
    private var session: VTDecompressionSession? = nil
    let format: VideoFormat
    var delegate: DecoderDelegate?
    
    init (format: VideoFormat) {
        self.format = format
    }
    
    func didReceiveNALUnit (_ nalu: NALUnit) {
        
        guard var tempBuffer = nalu.data as? NSData else {
            print("Couldn't cast NALU data to NSData")
            return
        }
        
        switch nalu.type {
            case .HEVC_PPS,
                 .AVC_PPS:
                didReceivePPS(memoryBlock: UnsafeMutableRawPointer(mutating: tempBuffer.bytes), length: tempBuffer.length)
            case .HEVC_SPS,
                 .AVC_SPS:
                didReceiveSPS(memoryBlock: UnsafeMutableRawPointer(mutating: tempBuffer.bytes), length: tempBuffer.length)
            case .HEVC_VPS:
                didReceiveVPS(memoryBlock: UnsafeMutableRawPointer(mutating: tempBuffer.bytes), length: tempBuffer.length)
            case .AVC_VCL_ISLICEA,
                 .AVC_VCL_ISLICEB,
                 .AVC_VCL_ISLICEC,
                 .AVC_VCL_ISLICE_IDR,
                 .HEVC_VCL_BLA_W_LP,
                 .HEVC_VCL_BLA_W_RADL,
                 .HEVC_VCL_BLA_N_LP,
                 .HEVC_VCL_IDR_W_RADL,
                 .HEVC_VCL_IDR_N_LP,
                 .HEVC_VCL_CRA:
                didReceiveVCL(data: tempBuffer, length: tempBuffer.length, referencePicture: true, timestamp: nalu.timestamp)
            case .HEVC_SEI,
                 .HEVC_PACI,
                 .HEVC_FU,
                 .AVC_RTP_FU_A,
                 .AVC_RTP_FU_B,
                 .AVC_AUD,
                 .AVC_SEI,
                 .HEVC_AP:
                break
            default:
                didReceiveVCL(data: tempBuffer, length: tempBuffer.length, referencePicture: false, timestamp: nalu.timestamp)
        }
        
    }
    
    func didReceivePPS (memoryBlock: UnsafeMutableRawPointer, length: Int) {
        ppsBuffer = [UInt8] (Data(bytes: memoryBlock, count: length))
        hasPPS = true
        didReceivePS()
    }
    
    func didReceiveVPS (memoryBlock: UnsafeMutableRawPointer, length: Int) {
        vpsBuffer = [UInt8] (Data(bytes: memoryBlock, count: length))
        hasVPS = true
        didReceivePS()
    }
    
    func didReceiveSPS (memoryBlock: UnsafeMutableRawPointer, length: Int) {
        spsBuffer = [UInt8] (Data(bytes: memoryBlock, count: length))
        hasSPS = true
        didReceivePS()
    }
    
    // Handles creating format description from parameter sets
    func didReceivePS () {
        
        guard hasPPS && hasSPS && (hasVPS || format == .H264) else {
            print("Missing PPS/SPS/VPS for format description")
            return
        }
        
        if format == .H264 {
            
            let parameterSetPointers : [UnsafePointer<UInt8>] = [ UnsafeRawPointer(spsBuffer!).bindMemory(to: UInt8.self, capacity: spsBuffer!.count), UnsafeRawPointer(ppsBuffer!).bindMemory(to: UInt8.self, capacity: ppsBuffer!.count) ]
            let parameterSetSizes : [Int] = [ spsBuffer!.count, ppsBuffer!.count ]
            
            guard CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, parameterSetPointers.count, parameterSetPointers, parameterSetSizes, Int32(AVC_PREFIX_SIZE), &formatDescription) == noErr else {
                print("CMVideoFormatDescriptionCreateFromH264ParameterSets failed")
                return
            }
            
        }
        else if format == .H265 {
            
            let parameterSetPointers : [UnsafePointer<UInt8>] = [ UnsafeRawPointer(vpsBuffer!).bindMemory(to: UInt8.self, capacity: vpsBuffer!.count), UnsafeRawPointer(spsBuffer!).bindMemory(to: UInt8.self, capacity: spsBuffer!.count), UnsafeRawPointer(ppsBuffer!).bindMemory(to: UInt8.self, capacity: ppsBuffer!.count) ]
            let parameterSetSizes : [Int] = [ vpsBuffer!.count, spsBuffer!.count, ppsBuffer!.count ]
            
            guard CMVideoFormatDescriptionCreateFromHEVCParameterSets(kCFAllocatorDefault, parameterSetPointers.count, parameterSetPointers, parameterSetSizes, Int32(AVC_PREFIX_SIZE), nil, &formatDescription) == noErr else {
                print("CMVideoFormatDescriptionCreateFromHEVCParameterSets failed")
                return
            }
            
        }
        
        if session != nil {
            if !VTDecompressionSessionCanAcceptFormatDescription(session!, formatDescription!) {
                // TODO: video format changed => tear down & restore the session
            }
            return
        }
        
        // Create the decompression session here,
        // we've got everything we need
        let destinationPixelBufferAttributes = NSMutableDictionary()
        destinationPixelBufferAttributes.setValue(NSNumber(value: kCVPixelFormatType_32BGRA), forKey: kCVPixelBufferPixelFormatTypeKey as String)
        
        let callback: VTDecompressionOutputCallback = {(
            decompressionOutputRefCon: UnsafeMutableRawPointer?,
            sourceFrameRefCon: UnsafeMutableRawPointer?,
            status: OSStatus,
            infoFlags: VTDecodeInfoFlags,
            imageBuffer: CVImageBuffer?,
            presentationTimeStamp: CMTime,
            duration: CMTime) in
                        
            guard status == 0 else {
                // Returning here automatically retains the last successfully
                // decoded frame on the screen
                print("Decoding result: \(status)")
                return
            }
            
            let decoder: VTDecoder = Unmanaged<VTDecoder>.fromOpaque(decompressionOutputRefCon!).takeUnretainedValue()
            decoder.didDecodeFrame(imageBuffer: imageBuffer, presentationTimeStamp: presentationTimeStamp, presentationDuration: duration)
            
        }
        
        var outputCallback = VTDecompressionOutputCallbackRecord(decompressionOutputCallback: callback, decompressionOutputRefCon: Unmanaged.passUnretained(self).toOpaque())
        
        let sessionResult = VTDecompressionSessionCreate(nil, formatDescription!, NSMutableDictionary(), destinationPixelBufferAttributes, &outputCallback, &session)
        
        if sessionResult != 0 {
            print("Session result: \(sessionResult)")
        }
        
    }
    
    // Appends the provided memory block to the VCL buffer, converting
    // it to AVCC format (with 4-byte data length header)
    func didReceiveVCL (data: NSData, length: Int, referencePicture: Bool, timestamp: CMTime) {
        
        guard session != nil else {
            print("Skipping VCL because no decompression session is available")
            return
        }
        
        var blockBufferLoc: CMBlockBuffer? = nil
        
        // Prepare AVCC prefix bytes
        var bigI = Int32(length).bigEndian
        
        // Clean the buffer
        CMBlockBufferCreateEmpty(nil, 0, kCMBlockBufferPermitEmptyReferenceFlag, &blockBufferLoc)
        
        // Reserve memory for AVC length prefix
        guard CMBlockBufferAppendMemoryBlock(blockBufferLoc!, nil, AVC_PREFIX_SIZE, kCFAllocatorDefault, nil, 0, AVC_PREFIX_SIZE, 0) == noErr else {
            print("CMBlockBufferAppendMemoryBlock failed for AVCC prefix")
            fatalError()
        }
        
        // Fill AVC length prefix memory block
        guard CMBlockBufferReplaceDataBytes(&bigI, blockBufferLoc!, 0, AVC_PREFIX_SIZE) == noErr else {
            print("CMBlockBufferReplaceDataBytes failed for AVCC prefix")
            fatalError()
        }
        
        // Append the provided memory block, starting at AVCC header length byte
        guard CMBlockBufferAppendMemoryBlock(blockBufferLoc!, UnsafeMutableRawPointer(mutating: data.bytes), length, kCFAllocatorNull, nil, 0, length, 0) == noErr else {
            print("CMBlockBufferAppendMemoryBlock failed for block data")
            fatalError()
        }
        
        // Construct timing and sample size info
        // TODO: set decodeTimestamp according to the sequenceNumber of the RTP packet
        var timingInfo = CMSampleTimingInfo(duration:kCMTimeIndefinite, presentationTimeStamp:timestamp, decodeTimeStamp:kCMTimeInvalid)
        var sampleSize = [CMBlockBufferGetDataLength(blockBufferLoc!)]
        
        // Create sample buffer, packaging together the frame data
        // and format description
        var sampleBuffer: CMSampleBuffer? = nil
        CMSampleBufferCreate(kCFAllocatorDefault, blockBufferLoc!, true, nil, nil, formatDescription, 1, 1, &timingInfo, 1, &sampleSize, &sampleBuffer)
        
        var infoFlags = VTDecodeInfoFlags(rawValue: 0)
        let decompressionResult = VTDecompressionSessionDecodeFrame(session!, sampleBuffer!, [._EnableAsynchronousDecompression], nil, &infoFlags)
        
        if decompressionResult != 0 {
            print("Decompression result: \(decompressionResult)")
        }
        
    }
    
    func didDecodeFrame (imageBuffer: CVImageBuffer?, presentationTimeStamp: CMTime, presentationDuration: CMTime) {
        
        guard imageBuffer != nil else {
            print("No image buffer received from decoder")
            return
        }
        
        var timingInfo = CMSampleTimingInfo(duration:kCMTimeIndefinite, presentationTimeStamp: presentationTimeStamp, decodeTimeStamp: kCMTimeInvalid)
        
        var format: CMVideoFormatDescription? = nil
        let formatDescriptionResult = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, imageBuffer!, &format)
        
        guard formatDescriptionResult == 0 && format != nil else {
            print("CMVideoFormatDescription could not be created (\(formatDescriptionResult))")
            return
        }
        
        var sampleBuffer: CMSampleBuffer? = nil
        let sampleBufferResult = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, imageBuffer!, true, nil, nil, format!, &timingInfo, &sampleBuffer)
        
        guard sampleBufferResult == 0 else {
            print("Sample buffer could not be created (\(sampleBufferResult))")
            return
        }
        
        self.delegate?.didDecodeFrame(sampleBuffer: sampleBuffer!)
    }
    
}
