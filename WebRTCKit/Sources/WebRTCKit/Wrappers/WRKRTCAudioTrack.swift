import WebRTC

public protocol WRKRTCAudioTrack: AnyObject, WRKRTCMediaStreamTrack {
    
}

final class WRKRTCAudioTrackImpl: WRKRTCAudioTrack, @unchecked Sendable {
    
    private let _audioTrack: RTCAudioTrack
    private let queue = WebRTCActor.queue
    
    public let source: MediaTrackSource
    
    var audioTrack: RTCAudioTrack {
        WebRTCActor.checkSync {
            _audioTrack
        }
    }
    
    public var isEnabled: Bool {
        get {
            WebRTCActor.checkSync {
                _audioTrack.isEnabled
            }
        }
        set {
            WebRTCActor.checkSync {
                _audioTrack.isEnabled = newValue
            }
        }
    }
    
    init(_ audioTrack: RTCAudioTrack, source: MediaTrackSource) {
        self._audioTrack = audioTrack
        self.source = source
    }
}
