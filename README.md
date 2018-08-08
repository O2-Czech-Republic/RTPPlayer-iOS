# FFmpeg-based RTP Video Stream Player for iOS

This is a simple (S)RTP video stream player for iOS with decoding pipeline optionally based on a custom version of FFmpeg ([https://github.com/O2-Czech-Republic/FFmpeg](https://github.com/O2-Czech-Republic/FFmpeg)) that adds very basic error resilience to HEVC decoding.


### Background
As part of the O2 Smart Box project ([https://www.o2.cz/osobni/en/541537-o2_smart_box](https://www.o2.cz/osobni/en/541537-o2_smart_box)) we developed our own framework for RTP stream playback on iOS.

RTP playback implementation on iOS unfortunately involves some complexity as native out-of-the-box playback functionality is mostly limited to HLS for streaming and MP4-containerized H.26x for file playback. 

Playing RTP stream on iOS essentially requires the app to parse the payload of each RTP packet, use its own logic to reassemble NAL units from Fragmentation Units, and provide these NAL units along with a `CMVideoFormatDescription` as `CMSampleBuffer`s to VideoToolbox (or AVFoundation).


### Architecture
#### RTP Streaming
The basic component of the (S)RTP session is the `RTPProcessor` (or `SRTPProcessor`) which is responsible for:
- transforming raw data packets (buffers) into `RTPPacket` structs
- and delivering these `RTPPacket`s to its delegate in correct order (i.e. this is where reordering happens)

The `RTPProcessor` accepts in its constructor a `RTPTransport` object, a class responsible for handling the underlying transport channel and its lifecycle.

#### RTP Parsing
The `RTPProcessor` dispatches each `RTPPacket` to its delegate (in this case it's the ViewController) which should pass it to a `VideoDefragmenter` responsible for re-assembling large NAL units that did not fit into a single RTP packet and were split by the producer (e.g. IP camera) into multiple Fragmentation Units.

The `VideoDefragmenter` provides its delegate (usually the decoder, although additional processing might be involved) with complete NAL units ready to be decoded.

#### Video Stream Decoding
Currently, two decoders are provided: `VTDecoder`, which is just a wrapper around the native iOS VideoToolbox, and `FFMpegDecoder` based on custom FFmpeg version ([https://github.com/O2-Czech-Republic/FFmpeg](https://github.com/O2-Czech-Republic/FFmpeg)) that adds very basic error resilience to HEVC decoding (natively not present in FFmpeg's HEVC codec).

Each decoder delivers fully decoded and ready frames (as `CMSampleBuffer`s) that are ready to be enqueued to the player (`AVSampleBufferDisplayLayer`).


### Stream transport
This code currently only supports two methods of delivery (transports) but adding another one is only a matter of impementing a new `RTPTransport`.
#### UDP unicast
In which the client sends a "hello" packet to the server and the server responds back with a stream of RTP packets. 

This enables the traversal of NATs along the way but the client must be able to accept incoming packets on the same UDP port it sent the hello packet from. 

Due to the connectionless nature of UDP, the server also expects to receive a heartbeat packet every once in a while to know that the client is still there.

#### HTTP progressive download
The app performs an HTTP `GET` request to a remote server that responds with `Transfer-Encoding: chunked` in response header (and `Content-Length` unset) and streams the RTP packets in the request body. 

```
GET /streams/1234567 HTTP/1.1
Connection: close
```
```
HTTP/1.1 200 OK
Transfer-Encoding: chunked
Content-Type: video/rtp

AGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIDEzIGxhenkgZG9ncy...
```

Because `Content-Length` is not set, HTTP clients will treat this as an unbounded response of undefined (and potentially infinite) size and return data chunks as long as some data is received within a specified timeout.

Our particular protocol always sends a 4-byte packet size first, followed immediately by the packet itself, followed by the size of the next packet and so on.

| Packet 1 length (4 bytes) | Packet 1 (.....) | Packet 2 length (4 bytes) | Packet 2 (.....) |
| --- | --- | --- | --- |

For more info see [https://en.wikipedia.org/wiki/Progressive_download](https://en.wikipedia.org/wiki/Progressive_download)

### Known limitations
- The decryption of packet payload in SRTP is not implemented. We're using a custom encryption scheme wich is not fully SRTP-compatible.
- This is still a proof-of-concept, so expect that some corner cases might produce unexpected behavior or crashes (think handling sequence resets, byte array slicing etc.).
