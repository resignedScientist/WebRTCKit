import WebRTC

/// The source where a media track is being recorded.
public enum MediaTrackSource {
    
    /// This track is being recorded locally on the device.
    case local
    
    /// This track is being recorded by our remote peer.
    case remote
}

public protocol WRKRTCVideoTrack: WRKRTCMediaStreamTrack {
    
    func add(_ renderer: RTCVideoRenderer)
}

final class WRKRTCVideoTrackImpl: WRKRTCVideoTrack {
    
    private let _videoTrack: RTCVideoTrack
    
    public let source: MediaTrackSource
    
    public var videoTrack: RTCVideoTrack {
        _videoTrack
    }
    
    public var isEnabled: Bool {
        get {
            _videoTrack.isEnabled
        }
        set {
            _videoTrack.isEnabled = newValue
        }
    }
    
    init(_ videoTrack: RTCVideoTrack, source: MediaTrackSource) {
        self._videoTrack = videoTrack
        self.source = source
    }
    
    func add(_ renderer: RTCVideoRenderer) {
        _videoTrack.add(renderer)
    }
}
