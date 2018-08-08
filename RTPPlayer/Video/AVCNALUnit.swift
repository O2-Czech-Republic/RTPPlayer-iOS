//
//  AVCNALUnit.swift
//  VideoStream
//
//  Created by Ondřej Šebelík on 02.08.18.
//  Copyright © 2018 O2 Czech Republic. All rights reserved.
//

import Foundation
import AVFoundation

struct AVCNALUnit: NALUnit {
    
    var data: Data?
    var timestamp: CMTime
    
    init (data: Data, timestamp: CMTime) {
        self.data = data
        self.timestamp = timestamp
    }
    
    var type: NALUType {
        return NALUType.init(rawValue: data![0] & 0x1f) ?? .VCL
    }
    
    var isForbiddenZeroBitSet: Bool {
        return data![0] & 0x80 == 0x80
    }
    
}
