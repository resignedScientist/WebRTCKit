import WebRTC

public protocol WRKRTCVideoTrack: WRKRTCMediaStreamTrack {
    
    func add(_ renderer: RTCVideoRenderer)
}

final class WRKRTCVideoTrackImpl: WRKRTCVideoTrack, @unchecked Sendable {
    
    private let _videoTrack: RTCVideoTrack
    private let queue = DispatchQueue(label: "com.webrtckit.WRKRTCVideoTrack")
    
    public var videoTrack: RTCVideoTrack {
        queue.sync {
            _videoTrack
        }
    }
    
    init(_ videoTrack: RTCVideoTrack) {
        self._videoTrack = videoTrack
    }
    
    func add(_ renderer: RTCVideoRenderer) {
        queue.sync {
            videoTrack.add(renderer)
        }
    }
}
