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
    
    public var isEnabled: Bool {
        get {
            queue.sync {
                _videoTrack.isEnabled
            }
        }
        set {
            queue.sync {
                _videoTrack.isEnabled = newValue
            }
        }
    }
    
    init(_ videoTrack: RTCVideoTrack) {
        self._videoTrack = videoTrack
    }
    
    func add(_ renderer: RTCVideoRenderer) {
        queue.sync {
            _videoTrack.add(renderer)
        }
    }
}
