//
//  FragmentedNALUnit.swift
//  VideoStream
//
//  Created by Ondřej Šebelík on 02.08.18.
//  Copyright © 2018 O2 Czech Republic. All rights reserved.
//

import Foundation
import AVFoundation

struct FragmentedNALU: NALUnit {    
    
    var type: NALUType = NALUType.FU
    var fragments: [NALUFragment]
    var timestamp: CMTime
    
    init (timestamp: CMTime) {
        self.timestamp = timestamp
        self.fragments = []
    }
    
    var data: Data? {
        
        var lastFragmentSequence: UInt16? = nil
        
        // According to RFC 7798, the reconstructed NAL unit
        // should only contain contiguous fragments (i.e. in case
        // the n-th fragment is lost, the resulting NAL unit should
        // only contain the first n-1 fragments)
        let sortedFragments = fragments.sorted(by: { (a, b) -> Bool in
                let seqA: UInt16 = a.sequenceNumber
                let seqB: UInt16 = b.sequenceNumber
                return seqA <= seqB
            })
            .filter({ (a) -> Bool in
                // TODO: handle sequence reset
                let included = (lastFragmentSequence == nil || lastFragmentSequence == a.sequenceNumber-1)
                lastFragmentSequence = a.sequenceNumber
                return included
            })
        
        if !sortedFragments.first!.isStartUnit {
            print("Skipping NALU due to missing starting fragment")
            return nil
        }
        
        var naluHeader = Data(bytes: sortedFragments.first!.naluHeader)
        
        // If some fragments were omitted, the forbidden zero
        // bit of the reconstructed NALU must be set to 1 to indicate
        // to the decoder that some data is missing. Fortunately,
        // the bit has the same position for both H.264/AVC and HEVC
        if sortedFragments.count != fragments.count {
            naluHeader[0] = naluHeader[0] | 0x80
            print("Setting forbidden zero bit to one because \(fragments.count - sortedFragments.count) packets are missing")
        }
        
        return sortedFragments
            .reduce(naluHeader) { (accumulator: Data, element: NALUFragment) -> Data in
                var data = accumulator
                data.append(element.payload)
                return data
        }
        
    }
    
    var isForbiddenZeroBitSet: Bool {
        return data![0] & 0x80 == 0x80
    }
    
}

protocol NALUFragment: NALUnit {
    
    var data: Data? { get }
    var sequenceNumber: UInt16 { get }
    var type: NALUType { get }
    var timestamp: CMTime { get }
    var header: UInt8 { get }
    var naluHeader: [UInt8] { get }
    var payload: Data { get }
    
}

extension NALUFragment {
    
    var isStartUnit: Bool {
        return header & 0x80 == 0x80
    }
    
    var isEndUnit: Bool {
        return header & 0x40 == 0x40
    }
    
    var isForbiddenZeroBitSet: Bool {
        return data![0] & 0x80 == 0x80
    }
    
}
