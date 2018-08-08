//
//  AVCDefragmenter.swift
//  VideoStream
//
//  Created by Ondřej Šebelík on 03.08.18.
//  Copyright © 2018 O2 Czech Republic. All rights reserved.
//

import Foundation
import AVFoundation

class AVCDefragmenter: VideoDefragmenter {
    
    
    override func didAssembleFU (_ nalu: FragmentedNALU) {
        
        guard let unitData = nalu.data else {
            print("Skipping fragmented NALU because it does not contain any data")
            return
        }
        
        delegate?.didReceiveNALUnit(AVCNALUnit(data: unitData, timestamp: nalu.timestamp))
        
    }
    
    override func didReceivePacket(_ data: Data?, timestamp: CMTime, sequenceNumber: UInt16) {
        
        guard data != nil else {
            print("No NALU data received")
            return
        }
        
        let nalu = AVCNALUnit(data: data!, timestamp: timestamp)
        
        if nalu.type == .AVC_RTP_FU_A || nalu.type == .AVC_RTP_FU_B {
            didReceiveFU(AVCNALUFragment(data: nalu.data!, timestamp: timestamp, sequenceNumber: sequenceNumber, type: nalu.type))
            return
        }
        
        self.delegate?.didReceiveNALUnit(nalu)
        
    }
    
}
