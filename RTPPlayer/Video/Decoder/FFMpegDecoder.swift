//
//  FFMpegDecoder.swift
//  VideoStream
//
//  Created by Ondřej Šebelík on 03.08.18.
//  Copyright © 2018 O2 Czech Republic. All rights reserved.
//

import Foundation
import FFmpeg
import UIKit

class FFMpegDecoder: Decoder {
    
    private var codec: UnsafeMutablePointer<AVCodec>!
    private var codecContext: UnsafeMutablePointer<AVCodecContext>!
    private var decoder: UnsafeMutableRawPointer!
    
    var delegate: DecoderDelegate?
    
    private var size: CGSize
    
    init (format: VideoFormat, size: CGSize) {
        
        self.size = size
        
        av_log_set_level(AV_LOG_ERROR)
        codec = (format == .H265) ? avcodec_find_decoder(AV_CODEC_ID_HEVC) : avcodec_find_decoder(AV_CODEC_ID_H264)
        
        guard codec != nil else {
            print("Codec not found")
            fatalError()
        }
        
        codecContext = avcodec_alloc_context3(codec)
        codecContext.pointee.thread_count = 2
        codecContext.pointee.error_concealment = FF_EC_FAVOR_INTER
        avcodec_open2(codecContext, codec, nil)
        
        guard codecContext != nil else {
            print("Could not allocate video codec context")
            fatalError()
        }
        
    }
    
    
    func didReceiveNALUnit(_ nalu: NALUnit) {
        
        guard nalu.data != nil else {
            print("Skipping empty NALU decoding")
            return
        }
        
        guard !nalu.isForbiddenZeroBitSet else {
            print("NALU data is corrupted, skipping")
            return
        }
        
        switch nalu.type {
            case .HEVC_FU,
                 .AVC_RTP_FU_A,
                 .AVC_RTP_FU_B,
                 .HEVC_AP,
                 .HEVC_PACI:
                break
            default:
                decodeNAL(data: nalu.data!, timestamp: nalu.timestamp)
        }
        
    }
    
    private func decodeNAL (data: Data, timestamp: CMTime) {
        
        guard var avPacket = getPacket(data: data, timestamp: timestamp) else {
            print("🎞💥 FFmpeg error: Could not create AVPacket from NALU data")
            return
        }
        
        var decodeResult = avcodec_send_packet(codecContext, &avPacket)
        
        if decodeResult < 0 {
            
            error(decodeResult, "avcodec_send_packet")
            
            if (decodeResult == -1094995529) {
                print("🎞 FFmpeg packet data: \(avPacket.buf.pointee.data)")
            }
            
            return
            
        }
        
        while decodeResult >= 0 {
            
            guard var frame: UnsafeMutablePointer<AVFrame>? = av_frame_alloc() else {
                print("🎞💥 FFmpeg error: Could not allocate memory for decoded frame")
                return
            }
            
            decodeResult = avcodec_receive_frame(codecContext, frame)
            
            if decodeResult == -EAGAIN || decodeResult == -EOF {
                continue
            }
            else if decodeResult < 0 {
                error(decodeResult)
                continue
            }
            else if decodeResult != 0 {
                error(decodeResult)
            }
            
            guard let pixelBuffer = pixelBufferFromAVFrame(frame: frame!.pointee) else {
                print("🎞💥 pixelBufferFromAVFrame failed")
                continue
            }
            
            // Just a note here: the presentation timestamp of the decoded frame
            // is assumed to use the same timescale as the decoded frame. This might
            // not necessarily be the case and it would be much better to pass this
            // information in every AVFrame
            didDecodePicture(pixelBuffer: pixelBuffer, timestamp: CMTimeMake(frame!.pointee.pts, timestamp.timescale))
            av_frame_free(UnsafeMutablePointer(mutating: &frame))
            
        }
        
    }
    
    private func didDecodePicture (pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        
        var timingInfo = CMSampleTimingInfo(duration:kCMTimeIndefinite, presentationTimeStamp: timestamp, decodeTimeStamp: kCMTimeInvalid)
        
        var format: CMVideoFormatDescription? = nil
        let formatDescriptionResult = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &format)
        
        guard formatDescriptionResult == 0 && format != nil else {
            print("CMVideoFormatDescription could not be created (\(formatDescriptionResult))")
            return
        }
        
        var sampleBuffer: CMSampleBuffer? = nil
        let sampleBufferResult = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, true, nil, nil, format!, &timingInfo, &sampleBuffer)
        
        guard sampleBufferResult == 0 else {
            print("Sample buffer could not be created (\(sampleBufferResult))")
            return
        }
        
        self.delegate?.didDecodeFrame(sampleBuffer: sampleBuffer!)
    
    }
    
    private func pixelBufferFromAVFrame (frame: AVFrame) -> CVPixelBuffer? {
        
        guard codecContext.pointee != nil else {
            print("🎞💥 Missing codec context")
            return nil
        }
        
        guard frame.data.0 != nil else {
            print("🎞💥 Received AVFrame with empty data")
            return nil
        }
        
        guard frame.linesize.0 != frame.linesize.1 else {
            print("🎞💥 AVFrame's line sizes do not match")
            return nil
        }
        
        // Prepare pixel buffer
        var pixelBuffer: CVPixelBuffer? = nil
        
        if (frame.linesize.1 != frame.linesize.2) {
            return nil
        }
        
        // Calculate sizes & allocate memory
        let srcPlaneSize = Int(frame.linesize.1 * frame.height/2)
        let dstPlaneSize = Int(srcPlaneSize * 2)
        let dstPlane = UnsafeMutablePointer<UInt8>.allocate(capacity: dstPlaneSize)
        
        // Interleave Cb and Cr plane
        for i in 0..<srcPlaneSize {
            dstPlane[2*i]=frame.data.1![i]
            dstPlane[2*i+1]=frame.data.2![i]
        }
        
        guard let pixelFormat = FFMpegDecoder.getPixelFormat(avPixelFormat: AVPixelFormat(rawValue: frame.format)) else {
            print("🎞💥 Unsupported pixel format")
            return nil
        }
        
        // Create the output pixel buffer
        let options: [CFString: Any] = [
            kCVPixelBufferBytesPerRowAlignmentKey: frame.linesize.0,
            kCVPixelBufferOpenGLESCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        
        let pixelBufferCreateResult = CVPixelBufferCreate(kCFAllocatorDefault,
                                                          Int(frame.width),
                                                          Int(frame.height),
                                                          pixelFormat,
                                                          options as CFDictionary,
                                                          &pixelBuffer)
        
        if pixelBufferCreateResult != kCVReturnSuccess {
            print("Could not create empty pixel buffer (status: \(pixelBufferCreateResult))")
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        let bytePerRowY = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer!, 0)
        let bytesPerRowUV = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer!, 1)
        
        // Copy frame data to 0-th plane (Y component)
        var base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer!, 0)
        memcpy(base, frame.data.0, bytePerRowY * Int(frame.height))
        
        // Copy frame data to 1st plane (Cb & Cr components)
        base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer!, 1)
        memcpy(base, dstPlane, bytesPerRowUV * Int(frame.height)/2)
        
        // Deallocate Cb and Cr buffer
        free(dstPlane)
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
        
    }
    
    private func getPacket (data: Data, timestamp: CMTime) -> AVPacket? {
        
        // According to https://www.ffmpeg.org/doxygen/3.4/group__lavc__decoding.html#ga58bc4bf1e0ac59e27362597e467efff3
        // "The input buffer, avpkt->data must be AV_INPUT_BUFFER_PADDING_SIZE larger than the actual read bytes because some optimized bitstream readers read 32 or 64 bits at once and could read over the end."
        let paddingArray = Array(repeating: UInt8(0x00), count: Int(AV_INPUT_BUFFER_PADDING_SIZE))
        let prefixArray: Array<UInt8> = [0x00, 0x00, 0x01]
        let naluArray = prefixArray + Array(data)
        var frameArray = naluArray + paddingArray
        
        var avPacket = AVPacket()
        var avPacketData = av_malloc(naluArray.count)
        memcpy(avPacketData, frameArray, naluArray.count)
        
        let avPacketResult = av_packet_from_data(&avPacket, avPacketData?.bindMemory(to: UInt8.self, capacity: naluArray.count), Int32(naluArray.count))
        
        guard avPacketResult == 0 else {
            error(avPacketResult, "av_packet_from_data")
            return nil
        }
        
        avPacket.pts = timestamp.value
        
        return avPacket
        
    }
    
    private func error (_ errNo: Int32) {
        return error(errNo, "")
    }
    
    private func error (_ errNo: Int32, _ context: String) {
        
        var errBuf = Array(repeating: Int8(0), count: 100)
        av_strerror(errNo, &errBuf, 100)
        
        let errData = Data(bytes: &errBuf, count: 100)
        let string = String(data: errData, encoding: .utf8)
        print("🎞💥 FFMpeg error (\(context)): \(string!.trimmingCharacters(in: CharacterSet(charactersIn: "ABCDEF"))) (\(errNo))")
        
    }
    
    fileprivate static func getPixelFormat (avPixelFormat: AVPixelFormat) -> OSType? {
        switch avPixelFormat {
        case AV_PIX_FMT_YUV420P:
            return kCVPixelFormatType_420YpCbCr8Planar
        case AV_PIX_FMT_UYVY422:
            return kCVPixelFormatType_422YpCbCr8
        case AV_PIX_FMT_BGRA:
            return kCVPixelFormatType_32BGRA
        case AV_PIX_FMT_NV12,
             AV_PIX_FMT_YUVJ420P,
             AV_PIX_FMT_YUVA420P:
            return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        default:
            return nil
        }
    }
    
}
