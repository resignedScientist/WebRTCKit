import WebRTC

public protocol WRKRTCMediaStreamTrack: AnyObject, Sendable {
    
    /// The enabled state of the track. If set to false, this track is muted / off.
    var isEnabled: Bool { get set }
    
    /// The source where this track is coming from.
    var source: MediaTrackSource { get }
}
