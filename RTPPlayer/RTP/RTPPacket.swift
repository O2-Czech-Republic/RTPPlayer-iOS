//
//  RTPPacket.swift
//  VideoStream
//
//  Created by Ondřej Šebelík on 10.04.18.
//  Copyright © 2018 O2 Czech Republic. All rights reserved.
//

import Foundation

// Represents a single RTP packet
struct RTPPacket {    
    // The raw payload of the video packet bearing
    // stream data
    var payload: Data
    // Sequece number
    var sequence: UInt16
    // Synchronization source
    var ssrc: UInt32
    // Contributing source
    var csrc: [UInt32]
    // Packet timestamp
    var timestamp: UInt32
    // Optional header extensions
    var extensions: Data?
}
