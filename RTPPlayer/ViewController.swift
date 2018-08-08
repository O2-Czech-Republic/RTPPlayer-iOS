//
//  ViewController.swift
//  VideoStream
//
//  Created by Ondřej Šebelík on 08/03/2018.
//  Copyright © 2018 O2 Czech Republic. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    private let SERVER_ADDRESS = "127.0.0.1"
    private let SERVER_PORT: UInt16 = 8001
    
    @IBOutlet weak var playerContainer: UIView!
    
    var playerLayer: AVSampleBufferDisplayLayer!
    private var hasTimeSync: Bool = false

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscapeRight
    }

    override var shouldAutorotate: Bool {
        return true
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()

        // Force landscape orientation
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        // Force landscape orientation

        playerLayer = AVSampleBufferDisplayLayer()

        playerLayer.backgroundColor = UIColor.red.cgColor
        playerLayer.videoGravity = .resizeAspect
        playerContainer.layer.addSublayer(playerLayer)

        var timebase: CMTimebase? = nil
        CMTimebaseCreateWithMasterClock(kCFAllocatorDefault, CMClockGetHostTimeClock(), &timebase)
        playerLayer.controlTimebase = timebase

        CMTimebaseSetRate(playerLayer.controlTimebase!, 1.0)
        CMTimebaseSetTime(playerLayer.controlTimebase!, kCMTimeZero)

        setupDecoder()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playerLayer.frame = self.view.frame
        playerLayer.bounds = self.view.bounds
    }
    
    
    var defragmenter: VideoDefragmenter?
    var decoder: Decoder?
    
    func setupDecoder () {
        
        let transport = RTPTransportHTTP(server: SERVER_ADDRESS, port: SERVER_PORT)
        
        let rtp = SRTPProcessor(transport: transport, keySupplier: { (sid: UInt32, callback: SRTPKeySupplierCallback) in
            callback(nil)
        })
        
        rtp.delegate = self
        
        DispatchQueue.global(qos: .default).async {
            rtp.connect()
        }
        
        // TODO: obtain format from API or use reasonable
        // defaults or heuristic approach to determine
        // the incoming format
        let format: VideoFormat = .H265
        
        decoder = FFMpegDecoder(format: format, size: UIScreen.main.bounds.size)
        decoder!.delegate = self
        
        defragmenter = HEVCDefragmenter()
        defragmenter?.delegate = decoder
        
    }
    
}

extension ViewController: RTPDelegate {
    
    func didReceiveRTPPacket (packet: RTPPacket) {
        
        guard packet.payload.count > 0 else {
            print("Received packet with empty payload")
            return
        }
        
        defragmenter?.didReceivePacket(packet.payload, timestamp: CMTimeMake(Int64(packet.timestamp), 90000), sequenceNumber: packet.sequence)
        
    }
    
}

extension ViewController: DecoderDelegate {
    
    func didDecodeFrame (sampleBuffer: CMSampleBuffer) {
        
        if !hasTimeSync {
            let timestamp = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
            CMTimebaseSetTime(playerLayer.controlTimebase!, timestamp)
            hasTimeSync = true
        }
        
        DispatchQueue.main.async {
            self.playerLayer.enqueue(sampleBuffer)
        }
        
        if (playerLayer.status == .failed) {
            print("AVQueuedSampleBufferRenderingStatusFailed")
        }
        
    }
    
}
