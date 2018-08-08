//
//  HEVCDemuxer.swift
//  VideoStream
//
//  Created by Ondřej Šebelík on 02.08.18.
//  Copyright © 2018 O2 Czech Republic. All rights reserved.
//

import Foundation
import AVFoundation

class HEVCDefragmenter: VideoDefragmenter {
    
    
    override func didAssembleFU (_ nalu: FragmentedNALU) {
        
        guard let unitData = nalu.data else {
            print("Skipping fragmented NALU because it does not contain any data")
            return
        }
        
        delegate?.didReceiveNALUnit(HEVCNALUnit(data: unitData, timestamp: nalu.timestamp))
        
    }
    
    override func didReceivePacket(_ data: Data?, timestamp: CMTime, sequenceNumber: UInt16) {
         
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
