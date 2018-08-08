//
//  UDPTransport.swift
//  VideoStream
//
//  Created by Ondřej Šebelík on 31.07.18.
//  Copyright © 2018 O2 Czech Republic. All rights reserved.
//

import Foundation

class RTPTransportUDP: RTPTransport {
    
    public var delegate: RTPTransportDelegate?
    
    static let HELLO_PACKET: Data = Data(base64Encoded: "SGVsbG8=")!
    static let BUFFER_SIZE: Int = 256*1024
    static var KEEPALIVE_INTERVAL: Double = 3
    
    private var udpcl: UDPClient?
    
    private var remoteAddress: String = ""
    private var remotePort: UInt16 = 0
    
    private var lastKeepaliveTimestamp: Double = 0
    
    
    init (server: String, port: UInt16) {
        remoteAddress = server
        remotePort = port
    }
    
    func connect () {
        
        udpcl = try? UDPClient(address: remoteAddress, port: remotePort)
        _ = udpcl?.send(RTPTransportUDP.HELLO_PACKET)
        
        while (udpcl != nil) {
            
            guard let data = udpcl?.receive(RTPTransportUDP.BUFFER_SIZE) else {
                print("No data received")
                continue
            }
            
            delegate?.datagramReceived(data)
            heartbeat()
            
        }
        
    }
    
    func disconnect () {
        print("Closing UDP connection")
        udpcl?.disconnect()
    }
    
    func heartbeat () {
        
        guard Date.timeIntervalSinceReferenceDate - lastKeepaliveTimestamp >= RTPTransportUDP.KEEPALIVE_INTERVAL else {
            return
        }
        
        lastKeepaliveTimestamp = Date.timeIntervalSinceReferenceDate
        _ = udpcl?.send(RTPTransportUDP.HELLO_PACKET)
        
    }
    
}
