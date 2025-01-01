import WebRTC

public enum MediaTrackSource {
    case local
    case remote
}

public protocol WRKRTCVideoTrack: WRKRTCMediaStreamTrack {
    
    func add(_ renderer: RTCVideoRenderer)
}

final class WRKRTCVideoTrackImpl: WRKRTCVideoTrack, @unchecked Sendable {
    
    private let _videoTrack: RTCVideoTrack
    private let queue = DispatchQueue(label: "com.webrtckit.WRKRTCVideoTrack")
    
    public let source: MediaTrackSource
    
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
    
    init(_ videoTrack: RTCVideoTrack, source: MediaTrackSource) {
        self._videoTrack = videoTrack
        self.source = source
    }
    
    func add(_ renderer: RTCVideoRenderer) {
        queue.sync {
            _videoTrack.add(renderer)
        }
    }
}
