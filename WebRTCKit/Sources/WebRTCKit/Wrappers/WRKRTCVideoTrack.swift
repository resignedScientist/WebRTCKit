import WebRTC

public protocol WRKRTCVideoTrack: WRKRTCMediaStreamTrack {
    
    func add(_ renderer: RTCVideoRenderer)
}

final class WRKRTCVideoTrackImpl: WRKRTCVideoTrack {
    
    public let videoTrack: RTCVideoTrack
    
    init(_ videoTrack: RTCVideoTrack) {
        self.videoTrack = videoTrack
    }
    
    func add(_ renderer: RTCVideoRenderer) {
        videoTrack.add(renderer)
    }
}
