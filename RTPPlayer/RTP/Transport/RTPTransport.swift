//
//  RTPTransport.swift
//  VideoStream
//
//  Created by Ondřej Šebelík on 31.07.18.
//  Copyright © 2018 O2 Czech Republic. All rights reserved.
//

protocol RTPTransport {
    var delegate: RTPTransportDelegate? { get set }
    func connect()
    func disconnect()
}

protocol RTPTransportDelegate {
    func datagramReceived (_ data: [UInt8])
}
