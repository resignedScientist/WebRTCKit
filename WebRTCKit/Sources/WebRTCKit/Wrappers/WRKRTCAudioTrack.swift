import WebRTC

public protocol WRKRTCAudioTrack: AnyObject, WRKRTCMediaStreamTrack {
    
}

final class WRKRTCAudioTrackImpl: WRKRTCAudioTrack {
    
    private let _audioTrack: RTCAudioTrack
    
    public let source: MediaTrackSource
    
    var audioTrack: RTCAudioTrack {
        _audioTrack
    }
    
    public var isEnabled: Bool {
        get {
            _audioTrack.isEnabled
        }
        set {
            _audioTrack.isEnabled = newValue
        }
    }
    
    init(_ audioTrack: RTCAudioTrack, source: MediaTrackSource) {
        self._audioTrack = audioTrack
        self.source = source
    }
}
