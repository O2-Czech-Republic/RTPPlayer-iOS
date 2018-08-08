//
//  UDPClient.swift
//  VideoStream
//
//  Created by Ondřej Šebelík on 26.06.18.
//  Copyright © 2018 O2 Czech Republic. All rights reserved.
//

import Foundation

class UDPClient {
    
    private var remoteAddress = in_addr(s_addr: 0)
    private var remotePort: UInt16 = 0
    
    private var localPort: UInt16 = 12345
    
    private var sock: Int32
    
    var address: sockaddr_in
    
    init(address: String, port: UInt16) throws {
        
        // Convert string IP to in_addr struct
        inet_aton(address, &remoteAddress)
        
        // Store remote port
        remotePort = port
        
        // Create UDP (SOCK_DGRAM) socket
        sock = socket(AF_INET, SOCK_DGRAM, 0)
        
        self.address = sockaddr_in(
            sin_len:    __uint8_t(MemoryLayout<sockaddr_in>.size),
            sin_family: sa_family_t(AF_INET),
            sin_port:   UDPClient.htons(value: remotePort),
            sin_addr:   remoteAddress,
            sin_zero:   ( 0, 0, 0, 0, 0, 0, 0, 0 )
        )
        
        var localAddress = sockaddr_in()
        memset(&localAddress, 0, MemoryLayout<sockaddr_in>.size)
        localAddress.sin_family = sa_family_t(AF_INET)
        localAddress.sin_addr.s_addr = INADDR_ANY.bigEndian
        localAddress.sin_port = in_port_t(localPort)
        
        _ = withUnsafeMutablePointer(to: &localAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                if connect(sock, $0, socklen_t(MemoryLayout.size(ofValue: localAddress))) != 0 {
                    print("Couldnt bind local address")
                }
            }
        }

    }
    
    static func htons(value: CUnsignedShort) -> CUnsignedShort {
        return (value << 8) + (value >> 8);
    }
    
    func send (_ message: Data) -> Int {
        
        let socketLength = socklen_t(address.sin_len)
        
        return message.withUnsafeBytes { (messagePointer: UnsafePointer<Int8>) in
        
            return withUnsafeMutablePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    // Send message
                    return sendto(sock, messagePointer, message.count, 0, $0, socketLength)
                }
            }
            
        }
        
    }
    
    func receive (_ size: Int) -> [UInt8]? {
        
        var buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        let bytesReceived = recv(sock, buffer, size, 0)
        
        guard bytesReceived > 0 else {
            print("No data received")
            return nil
        }
        
        return Array(UnsafeBufferPointer(start: buffer, count: bytesReceived))
        
    }
    
    func disconnect () {
        close(sock)
    }

    /**
     Necessary cleanup performed in this method
     */
    deinit {
        close(sock)
    }

}
