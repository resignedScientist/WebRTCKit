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

final class WRKRTCVideoTrackImpl: WRKRTCVideoTrack, @unchecked Sendable {
    
    private let _videoTrack: RTCVideoTrack
    private let queue = WebRTCActor.queue
    
    public let source: MediaTrackSource
    
    public var videoTrack: RTCVideoTrack {
        WebRTCActor.checkSync {
            _videoTrack
        }
    }
    
    public var isEnabled: Bool {
        get {
            WebRTCActor.checkSync {
                _videoTrack.isEnabled
            }
        }
        set {
            WebRTCActor.checkSync {
                _videoTrack.isEnabled = newValue
            }
        }
    }
    
    init(_ videoTrack: RTCVideoTrack, source: MediaTrackSource) {
        self._videoTrack = videoTrack
        self.source = source
    }
    
    func add(_ renderer: RTCVideoRenderer) {
        WebRTCActor.checkSync {
            _videoTrack.add(renderer)
        }
    }
}
