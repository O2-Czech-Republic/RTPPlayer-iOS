//
//  HEVCDemuxer.swift
//  VideoStream
//
//  Created by Ondřej Šebelík on 02.08.18.
//  Copyright © 2018 Smartbox. All rights reserved.
//

import Foundation
import AVFoundation

class HEVCDefragmenter: VideoDefragmenter {
    
    override func didReceivePacket(_ data: Data?, timestamp: CMTime, sequenceNumber: UInt16) {
        
        print("HEVCDemuxer: Received packet with timestamp \(timestamp)")
        
        guard data != nil else {
            print("No NALU data received")
            return
        }
        
        let nalu = HEVCNALUnit(data: data!, timestamp: timestamp)
        
        if nalu.type == .HEVC_FU {
            didReceiveFU(HEVCNALUFragment(data: nalu.data!, timestamp: timestamp, sequenceNumber: sequenceNumber))
            return
        }
        
        self.delegate?.didReceiveNALUnit(nalu)
        
    }
    
}
