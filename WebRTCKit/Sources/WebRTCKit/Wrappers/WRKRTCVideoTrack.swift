import WebRTC

public protocol WRKRTCVideoTrack: WRKRTCMediaStreamTrack {
    
    func add(_ renderer: RTCVideoRenderer)
}

final class WRKRTCVideoTrackImpl: WRKRTCVideoTrack, @unchecked Sendable {
    
    public let videoTrack: RTCVideoTrack
    private let queue = DispatchQueue(label: "com.webrtckit.WRKRTCVideoTrack")
    
    init(_ videoTrack: RTCVideoTrack) {
        self.videoTrack = videoTrack
    }
    
    func add(_ renderer: RTCVideoRenderer) {
        queue.sync {
            videoTrack.add(renderer)
        }
    }
}
