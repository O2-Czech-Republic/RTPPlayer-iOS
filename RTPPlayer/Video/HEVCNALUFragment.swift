//
//  HEVCNALUFragment.swift
//  VideoStream
//
//  Created by Ondřej Šebelík on 02.08.18.
//  Copyright © 2018 O2 Czech Republic. All rights reserved.
//

import Foundation
import AVFoundation

struct HEVCNALUFragment: NALUFragment {
    
    var data: Data?
    var sequenceNumber: UInt16
    var type: NALUType = .HEVC_FU
    var timestamp: CMTime
    
    init (data: Data, timestamp: CMTime, sequenceNumber: UInt16) {
        self.data = data
        self.timestamp = timestamp
        self.sequenceNumber = sequenceNumber
    }
    
    var header: UInt8 {
        return data![2]
}
    
    var payload: Data {
        return data![3...]
    }
    
    var naluType: UInt8 {
        return header & 0x3f
    }
    
    var naluHeader: [UInt8] {
        return [ ((data![0] & 0x81) | (naluType << 1)), data![1] ]
    }
    
}
