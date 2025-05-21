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
