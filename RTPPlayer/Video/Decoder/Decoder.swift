//
//  Decoder.swift
//  VideoStream
//
//  Created by Ondřej Šebelík on 06.08.18.
//  Copyright © 2018 O2 Czech Republic. All rights reserved.
//

import Foundation
import AVFoundation

protocol Decoder: VideoDemuxerDelegate {
    var delegate: DecoderDelegate? { get set }
}

protocol DecoderDelegate {
    func didDecodeFrame (sampleBuffer: CMSampleBuffer)
}
