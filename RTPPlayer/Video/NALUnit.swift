//
//  NALUnit.swift
//  VideoStream
//
//  Created by Ondřej Šebelík on 02.08.18.
//  Copyright © 2018 O2 Czech Republic. All rights reserved.
//

import Foundation
import AVFoundation

protocol NALUnit {
    
    // The NAL type ID of this unit
    var type: NALUType { get }
    
    // Raw NALU payload
    var data: Data? { get }
    
    // NALU presentation timestamp
    var timestamp: CMTime { get }
    
    // Forbidden zero bit for integrity check
    var isForbiddenZeroBitSet: Bool { get }
    
}


// There are 2 basic types of NAL units:
//      - VCL (video coding layer) carry image information
//      - non-VCL carry metadata, most notably
//          - Video parameter set (VPS) - only HEVC/H.265
//          - Picture parameter set (PPS)
//          - Sequence parameter set (SPS)
enum NALUType: UInt8 {
    
    // Generic Fragmentation Unit
    case FU = 0xff
    
    // AVC non-VCL types for H.264 decoding
    case AVC_SEI = 6
    case AVC_SPS = 7
    case AVC_PPS = 8
    case AVC_AUD = 9
    
    // AVC VCL types of reference pictures
    case AVC_VCL_ISLICEA = 2
    case AVC_VCL_ISLICEB = 3
    case AVC_VCL_ISLICEC = 4
    case AVC_VCL_ISLICE_IDR = 5
    
    // RTP H.264 Fragmentation Units (RFC 6184)
    case AVC_RTP_FU_A = 28
    case AVC_RTP_FU_B = 29
    
    // HEVC NAL types for H.265 decoding
    case HEVC_VPS = 32 // Video Parameter Set
    case HEVC_SPS = 33 // Sequence Parameter Set
    case HEVC_PPS = 34 // Picture Parameter Set
    case HEVC_AUD = 35 // Access Unit Delimiter
    case HEVC_SEI = 39 // Supplemental Enhancement Information
    case HEVC_AP = 48 // RTP Aggregation Packet as per https://tools.ietf.org/html/draft-ietf-payload-rtp-h265-15#section-4.4.2
    case HEVC_FU = 49 // RTP Fragmentation Unit as per https://tools.ietf.org/html/draft-ietf-payload-rtp-h265-15#section-4.4.3
    case HEVC_PACI = 50 // Payload Content Information
    
    // HEVC VCL types of reference pictures
    case HEVC_VCL_BLA_W_LP = 16
    case HEVC_VCL_BLA_W_RADL = 17
    case HEVC_VCL_BLA_N_LP = 18
    case HEVC_VCL_IDR_W_RADL = 19
    case HEVC_VCL_IDR_N_LP = 20
    case HEVC_VCL_CRA = 21
    
    // Default type for frame data slice (VCL)
    case VCL = 0
    
}
