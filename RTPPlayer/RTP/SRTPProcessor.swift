//
//  SRTPClient.swift
//  VideoStream
//
//  Created by Ondřej Šebelík on 17.04.18.
//  Copyright © 2018 O2 Czech Republic. All rights reserved.
//

import Foundation

class SRTPProcessor: RTPProcessor {
    
    // HMAC tag size in bits
    private let MAC_SIZE: Int = 128
    // Nonce size in bits
    private let NONCE_SIZE: Int = 64
    
    // keys is a map of encryption keys for each Session ID
    private var keys: [UInt32:Data] = [:]
    
    // The callback responsible for delivering encryption keys
    private var keySupplier: SRTPKeySupplier
    
    init(transport: RTPTransport, keySupplier: @escaping SRTPKeySupplier) {
        self.keySupplier = keySupplier
        super.init(transport: transport)
    }
    
    override func datagramReceived(_ data: [UInt8]) {
        
        // Timestamp
        let timestamp = ByteUtil.bytesToUInt32(data[4...7])
        
        // Sequence number
        let sequence = ByteUtil.bytesToUInt16(data[2...3])
        
        // Synchronization source (SSRC)
        let ssrc = ByteUtil.bytesToUInt32(data[8...11])
        
        // HMAC
        let mac = Data(data.suffix(MAC_SIZE/8))
        
        // Session ID
        let sid = ByteUtil.bytesToUInt32(data[(data.count-(MAC_SIZE/8)-4)...(data.count-(MAC_SIZE/8))])
        
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
        var nonce: Data?
        
        // Extensions (marked by 4th bit of the RTP packet header)
        // add to the standard RTP header length
        if data[0] & 0x10 == 0x10 {
            let extensionCount = ByteUtil.bytesToUInt16(data[headerLength+2...headerLength+3])
            extensions = Data(bytes: data[headerLength+4...headerLength+4+Int(extensionCount*4)-1])
            headerLength = headerLength + 4 + (extensions?.count)!
            nonce = extensions![8...7+(NONCE_SIZE/8)]
        }
        
        // Asynchronously decrypts the payload
        decryptPacketPayload(payload: Data(bytes: data[headerLength...(data.count - (MAC_SIZE/8) - 5)]), sid: sid, nonce: nonce) { (decryptedPayload: Data?) in
            
            guard decryptedPayload != nil else {
                return
            }
            
            guard verifyMAC(mac: mac, payload: decryptedPayload!, additionalData: Data(data[...headerLength])) else {
                print("Unable to verify SRTP packet MAC")
                return
            }
            
            let packet = RTPPacket(payload: decryptedPayload!, sequence: sequence, ssrc: ssrc, csrc: csrc, timestamp: timestamp, extensions: extensions)
            
            didReceiveRTPPacket(packet)
            
        }
        
    }
    
    private func decryptPacketPayload (payload: Data, sid: UInt32, nonce: Data?, callback: (Data?) -> ()) {
        
        // Decryption is disabled for debugging purposes
        return callback(payload)
        
        getKeyForSID(sid: sid) { (key: Data?) in
            
            guard key != nil else {
                return callback(nil)
            }
            
            // NOTE: This is where you'd decrypt each RTP packet's
            // payload using some crypto library (OpenSSL, CommonCrypto...)
            return callback(payload)
            
        }
        
    }
    
    private func getKeyForSID (sid: UInt32, callback: (Data?) -> ()) {
        
        // Do not call the callback if we have the key cached
        if keys[sid] != nil {
            return callback(keys[sid])
        }
        
        keySupplier(sid) { (key: Data?) in
            
            guard key != nil else {
                return callback(nil)
            }
            
            keys[sid] = key!
            callback(key)
            
        }
        
    }
    
    private func verifyMAC (mac: Data, payload: Data, additionalData: Data?) -> Bool {
        // NOTE: This is where you'd verify each RTP packet's
        // HMAC using some crypto library (OpenSSL, CommonCrypto...)
        return true
    }
    
}

typealias SRTPKeySupplierCallback = (Data?) -> ()
typealias SRTPKeySupplier = (UInt32, SRTPKeySupplierCallback) -> ()
