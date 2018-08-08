//
//  RTPClient.swift
//  VideoStream
//
//  Created by Ondřej Šebelík on 10.04.18.
//  Copyright © 2018 O2 Czech Republic. All rights reserved.
//

import Foundation

// Responsible for receiving packets from the underlying
// transport, reordering them, if necessary, and supplying
// the delegate with correctly ordered stream of RTP packets
class RTPProcessor: NSObject, RTPTransportDelegate {
    
    private var receivedPackets: UInt = 0
    private var lostPackets: UInt = 0
    
    var transport: RTPTransport
    var delegate: RTPDelegate? = nil
    
    init (transport: RTPTransport) {
        self.transport = transport
    }
    
    func connect () {
        self.transport.delegate = self
        self.transport.connect()
    }
    
    func close () {
        self.transport.disconnect()
    }
    
    func datagramReceived (_ data: [UInt8]) {
        
        // Timestamp
        let timestamp = ByteUtil.bytesToUInt32(data[4...7])
        
        // Sequence number
        let sequence = ByteUtil.bytesToUInt16(data[2...3])
        
        // Synchronization source (SSRC)
        let ssrc = ByteUtil.bytesToUInt32(data[8...11])
        
        // Contributing source (CSRC)
        let csrcCount = data[0] & 0x0f
        var csrc: [UInt32] = []
        
        for i in 0 ..< csrcCount {
            let csrcOffset: Int = 12 + Int(i*4)
            let csrcBytes = data[csrcOffset...(csrcOffset+4)]
            csrc.append(ByteUtil.bytesToUInt32(csrcBytes))
        }
        
        // Total length of the header (offset to payload)
        var headerLength = Int(12 + csrcCount*4)
        var extensions: Data?
        
        // Extensions (marked by 4th bit of the RTP packet header)
        // add to the standard RTP header length
        if data[0] & 0x10 == 0x10 {
            let extensionCount = ByteUtil.bytesToUInt16(data[headerLength+2...headerLength+3])
            extensions = Data(bytes: data[headerLength+4...headerLength+4+Int(extensionCount*4)-1])
            headerLength = headerLength + 4 + Int(extensionCount*4)
        }
        
        let payload = Data(bytes: data[headerLength...])
        
        let packet = RTPPacket(payload: payload, sequence: sequence, ssrc: ssrc, csrc: csrc, timestamp: timestamp, extensions: extensions)
        
        didReceiveRTPPacket(packet)
        
    }
    
    let QUEUE_CAPACITY = 10
    var expectedRTPPacketSequence: UInt16? = nil
    var rtpPacketOrderQueue: [RTPPacket] = []
    
    // Decides whether a packet should be dispatched to the delegate
    // right away or appended to the queue
    func didReceiveRTPPacket (_ packet: RTPPacket) {
        
        receivedPackets = receivedPackets+1
        
        // First packet ever received, do not inspect sequence number
        guard expectedRTPPacketSequence != nil else {
            dispatchPacket(packet)
            return
        }
        
        // Packets that arrive after a packet with higher
        // sequence number are dropped
        if packet.sequence < expectedRTPPacketSequence! && expectedRTPPacketSequence! < UInt16.max - UInt16(QUEUE_CAPACITY) && packet.sequence <= QUEUE_CAPACITY {
            print("Dropping out-of-order packet (expected \(expectedRTPPacketSequence!) got \(packet.sequence))")
            return
        }
        
        // Next packet in sequence arrived,
        // flush the queue
        if expectedRTPPacketSequence == packet.sequence {
            dispatchPacket(packet)
            return
        }
        else {
            print("Expected packet didn't arrive")
        }
        
        // Push to queue
        pushToQueue(packet)
        
        // Check if there are expected packets in the queue
        // already, this needs to happend for every out-of-order
        // packet to avoid skipping some packets forever that would
        // consume space in the queue indefinitely
        // For this to work, the queue needs to be ordered
        if rtpPacketOrderQueue.first!.sequence == expectedRTPPacketSequence || rtpPacketOrderQueue.count >= QUEUE_CAPACITY {
            
            repeat {
                dispatchPacket(rtpPacketOrderQueue.removeFirst())
            }
            while (rtpPacketOrderQueue.first?.sequence == expectedRTPPacketSequence || rtpPacketOrderQueue.count >= QUEUE_CAPACITY)
            
        }
        
    }
    
    // Appends a packet to the queue and reorders it
    func pushToQueue (_ packet: RTPPacket) {
        
        rtpPacketOrderQueue.append(packet)
        
        rtpPacketOrderQueue.sort(by: { (a, b) -> Bool in
            let seqA: UInt16 = a.sequence
            let seqB: UInt16 = b.sequence
            return seqA <= seqB
        })
        
    }
    
    // Dispatches the packet to the delegate
    func dispatchPacket (_ packet: RTPPacket) {
        expectedRTPPacketSequence = UInt16((Int(packet.sequence) + 1) % 65535)
        delegate?.didReceiveRTPPacket(packet: packet)
    }
    
}

protocol RTPDelegate {
    func didReceiveRTPPacket (packet: RTPPacket)
}
