import WebRTC

public protocol WRKMediaStream: AnyObject, Sendable {
    
    var audioTracks: [WRKRTCAudioTrack] { get }
    
    var videoTracks: [WRKRTCVideoTrack] { get }
    
    func addAudioTrack(_ audioTrack: WRKRTCAudioTrack)
    
    func addVideoTrack(_ videoTrack: WRKRTCVideoTrack) async
}

final class WRKMediaStreamImpl: WRKMediaStream {
    
    let mediaStream: RTCMediaStream
    
    var audioTracks: [WRKRTCAudioTrack] {
        mediaStream.audioTracks.map {
            WRKRTCAudioTrackImpl($0)
        }
    }
    
    var videoTracks: [WRKRTCVideoTrack] {
        mediaStream.videoTracks.map {
            WRKRTCVideoTrackImpl($0)
        }
    }
    
    init(_ mediaStream: RTCMediaStream) {
        self.mediaStream = mediaStream
    }
    
    func addAudioTrack(_ audioTrack: WRKRTCAudioTrack) {
        if let audioTrack = (audioTrack as? WRKRTCAudioTrackImpl)?.audioTrack {
            mediaStream.addAudioTrack(audioTrack)
        }
    }
    
    func addVideoTrack(_ videoTrack: WRKRTCVideoTrack) async {
        if let videoTrack = (videoTrack as? WRKRTCVideoTrackImpl)?.videoTrack {
            mediaStream.addVideoTrack(videoTrack)
        }
    }
}
