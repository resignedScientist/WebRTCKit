/// The source where a media track is being recorded.
public enum MediaTrackSource: Sendable {
    
    /// This track is being recorded locally on the device.
    case local
    
    /// This track is being recorded by our remote peer.
    case remote
}
