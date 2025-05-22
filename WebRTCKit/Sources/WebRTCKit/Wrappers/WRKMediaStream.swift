import WebRTC

public protocol WRKMediaStream: AnyObject, Sendable {
    
    var source: MediaTrackSource { get }
    
    var audioTracks: [WRKRTCAudioTrack] { get }
    
    var videoTracks: [WRKRTCVideoTrack] { get }
    
    func addAudioTrack(_ audioTrack: WRKRTCAudioTrack) async
    
    func addVideoTrack(_ videoTrack: WRKRTCVideoTrack) async
}

final class WRKMediaStreamImpl: WRKMediaStream, @unchecked Sendable {
    
    let mediaStream: RTCMediaStream
    let source: MediaTrackSource
    private let queue = WebRTCActor.queue
    
    var audioTracks: [WRKRTCAudioTrack] {
        WebRTCActor.checkSync {
            mediaStream.audioTracks.map {
                WRKRTCAudioTrackImpl($0, source: source)
            }
        }
    }
    
    var videoTracks: [WRKRTCVideoTrack] {
        WebRTCActor.checkSync {
            mediaStream.videoTracks.map {
                WRKRTCVideoTrackImpl($0, source: source)
            }
        }
    }
    
    init(_ mediaStream: RTCMediaStream, source: MediaTrackSource) {
        self.mediaStream = mediaStream
        self.source = source
    }
    
    func addAudioTrack(_ audioTrack: WRKRTCAudioTrack) async {
        return await withCheckedContinuation { continuation in
            WebRTCActor.checkAsync {
                if let audioTrack = (audioTrack as? WRKRTCAudioTrackImpl)?.audioTrack {
                    self.mediaStream.addAudioTrack(audioTrack)
                }
                continuation.resume()
            }
        }
    }
    
    func addVideoTrack(_ videoTrack: WRKRTCVideoTrack) async {
        return await withCheckedContinuation { continuation in
            WebRTCActor.checkAsync {
                if let videoTrack = (videoTrack as? WRKRTCVideoTrackImpl)?.videoTrack {
                    self.mediaStream.addVideoTrack(videoTrack)
                }
                continuation.resume()
            }
        }
    }
}
