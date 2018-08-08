//
//  VideoDemuxer.swift
//  VideoStream
//
//  Created by Ondřej Šebelík on 02.08.18.
//  Copyright © 2018 O2 Czech Republic. All rights reserved.
//

import Foundation
import AVFoundation

class VideoDefragmenter {
    
    var delegate: VideoDemuxerDelegate?
    
    // Intermediate container for holding
    // NALU fragments
    private var fragmentedNALU: FragmentedNALU? = nil
    
    func didReceivePacket(_ data: Data?, timestamp: CMTime, sequenceNumber: UInt16) { }
    
    // Implementing classes are expected to override
    // this method to perform the final dispatch of
    // the assembled NALU
    func didAssembleFU (_ nalu: FragmentedNALU) { }
    
    
    // This function assembles complete NAL units
    // from NALU fragments
    func didReceiveFU (_ fragment: NALUFragment) {
        
        // If the current fragmented NALU timestamp does not
        // match the received unit, close the current NALU
        if fragmentedNALU != nil && fragmentedNALU!.timestamp != fragment.timestamp {
            didAssembleFU(fragmentedNALU!)
            fragmentedNALU = nil
        }
        
        if fragmentedNALU == nil {
            fragmentedNALU = FragmentedNALU(timestamp: fragment.timestamp)
        }
        
        guard fragmentedNALU != nil else {
            print("No previous fragment found, dropping fragment")
            return
        }
        
        fragmentedNALU!.fragments.append(fragment)
        
    }
    
}

protocol VideoDemuxerDelegate {
    func didReceiveNALUnit (_ nalu: NALUnit)
}
