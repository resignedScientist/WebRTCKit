import WebRTC

@MainActor
public protocol WRKMediaStream: AnyObject, Sendable {
    
    var source: MediaTrackSource { get }
    
    var audioTracks: [WRKRTCAudioTrack] { get }
    
    var videoTracks: [WRKRTCVideoTrack] { get }
    
    func addAudioTrack(_ audioTrack: WRKRTCAudioTrack) async
    
    func addVideoTrack(_ videoTrack: WRKRTCVideoTrack) async
}

final class WRKMediaStreamImpl: WRKMediaStream {
    
    let mediaStream: RTCMediaStream
    let source: MediaTrackSource
    
    var audioTracks: [WRKRTCAudioTrack] {
        mediaStream.audioTracks.map {
            WRKRTCAudioTrackImpl($0, source: source)
        }
    }
    
    var videoTracks: [WRKRTCVideoTrack] {
        mediaStream.videoTracks.map {
            WRKRTCVideoTrackImpl($0, source: source)
        }
    }
    
    init(_ mediaStream: RTCMediaStream, source: MediaTrackSource) {
        self.mediaStream = mediaStream
        self.source = source
    }
    
    func addAudioTrack(_ audioTrack: WRKRTCAudioTrack) async {
        if let audioTrack = (audioTrack as? WRKRTCAudioTrackImpl)?.audioTrack {
            self.mediaStream.addAudioTrack(audioTrack)
        }
    }
    
    func addVideoTrack(_ videoTrack: WRKRTCVideoTrack) async {
        if let videoTrack = (videoTrack as? WRKRTCVideoTrackImpl)?.videoTrack {
            mediaStream.addVideoTrack(videoTrack)
        }
    }
}
