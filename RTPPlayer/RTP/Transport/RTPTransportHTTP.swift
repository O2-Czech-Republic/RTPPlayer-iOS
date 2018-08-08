//
//  SRTPClientTCP.swift
//  VideoStream
//
//  Created by Ondřej Šebelík on 20.07.18.
//  Copyright © 2018 O2 Czech Republic. All rights reserved.
//

import Foundation

class RTPTransportHTTP: NSObject, RTPTransport, URLSessionDataDelegate {
    
    public var delegate: RTPTransportDelegate?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    
    private var remoteAddress: String = ""
    private var remotePort: UInt16 = 0
    
    // Temp buffer
    private var intermediateBuffer = Data()
    private var expectedPacketLength: Int? = nil
    
    init (server: String, port: UInt16) {
        remoteAddress = server
        remotePort = port
    }
    
    // Initiates a connection to a remote server
    // providing RTP packets tunnelled through TCP
    func connect() {
        
        let sessionConfiguration = URLSessionConfiguration.default
        session = URLSession(configuration: sessionConfiguration, delegate:self, delegateQueue: nil)
        
        var url = URLComponents()
        url.scheme = "http"
        url.host = remoteAddress
        url.port = Int(remotePort)
        url.path = "/stream/123456789"
        
        var request = URLRequest(url: url.url!)
        request.httpMethod = "GET"
        request.timeoutInterval = 3600
        
        task = session!.dataTask(with: request)
        task!.resume()
        
    }
    
    // Closes the connection
    func disconnect() {
        task?.cancel()
    }
    
    // URLSessionDataDelegate methods
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        print("Got response: \(response)")
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        // Ignore empty data
        guard data.count > 0 else {
            return
        }
        
        intermediateBuffer = intermediateBuffer + data
        
        // We need at least 4 bytes to read the expected length
        // of the incoming packet
        guard intermediateBuffer.count > 4 else {
            print("Not enough intermediate data")
            return
        }
        
        expectedPacketLength = Int(ByteUtil.bytesToUInt32(ArraySlice(intermediateBuffer[0...3]) )) + 4
        
        // There is enough data for the entire expected packet
        // in the intermediate buffer
        while expectedPacketLength != nil && intermediateBuffer.count >= expectedPacketLength! {
            
            self.delegate?.datagramReceived(Array(intermediateBuffer[4...(expectedPacketLength!-1)]))
            
            intermediateBuffer = intermediateBuffer.subdata(in: expectedPacketLength!..<intermediateBuffer.count)
            
            // The buffer left is large enough to at least
            // hold the length prefix
            if (intermediateBuffer.count >= 4) {
                expectedPacketLength = Int(ByteUtil.bytesToUInt32(ArraySlice(intermediateBuffer[...3]) )) + 4
            }
            else {
                // The buffer that was left after slicing the last
                // complete packet is not even large enoiugh to hold
                // the length prefix
                expectedPacketLength = nil
            }
            
        }
        
    }
    
    // TODO: reconnect and/or handle error
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("Error: \(error)")
    }
    
}
