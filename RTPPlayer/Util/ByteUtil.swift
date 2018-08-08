//
//  File.swift
//  VideoStream
//
//  Created by Ondřej Šebelík on 31.07.18.
//  Copyright © 2018 O2 Czech Republic. All rights reserved.
//

class ByteUtil {
    
    static func bytesToUInt16 (_ bytes: ArraySlice<UInt8>) -> UInt16 {
        
        let bigEndianValue = bytes.withUnsafeBufferPointer {
            ($0.baseAddress!.withMemoryRebound(to: UInt16.self, capacity: 1) { $0 })
            }.pointee
        
        return UInt16(bigEndian: bigEndianValue)
        
    }
    
    static func bytesToUInt32 (_ bytes: ArraySlice<UInt8>) -> UInt32 {
        
        let bigEndianValue = bytes.withUnsafeBufferPointer {
            ($0.baseAddress!.withMemoryRebound(to: UInt32.self, capacity: 1) { $0 })
            }.pointee
        
        return UInt32(bigEndian: bigEndianValue)
        
    }
}
