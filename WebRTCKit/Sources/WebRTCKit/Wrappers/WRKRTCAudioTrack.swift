import WebRTC

public protocol WRKRTCAudioTrack: AnyObject, WRKRTCMediaStreamTrack {
    
}

final class WRKRTCAudioTrackImpl: WRKRTCAudioTrack, @unchecked Sendable {
    
    private let _audioTrack: RTCAudioTrack
    private let queue = DispatchQueue(label: "com.webrtckit.WRKRTCAudioTrack")
    
    public let source: MediaTrackSource
    
    var audioTrack: RTCAudioTrack {
        queue.sync {
            _audioTrack
        }
    }
    
    public var isEnabled: Bool {
        get {
            queue.sync {
                _audioTrack.isEnabled
            }
        }
        set {
            queue.sync {
                _audioTrack.isEnabled = newValue
            }
        }
    }
    
    init(_ audioTrack: RTCAudioTrack, source: MediaTrackSource) {
        self._audioTrack = audioTrack
        self.source = source
    }
}
