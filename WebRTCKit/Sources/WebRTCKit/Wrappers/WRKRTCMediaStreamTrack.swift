import WebRTC

public protocol WRKRTCMediaStreamTrack: AnyObject, Sendable {
    
    var isEnabled: Bool { get set }
    
    var source: MediaTrackSource { get }
}
