import WebRTC

public protocol WRKRTCAudioTrack: AnyObject, WRKRTCMediaStreamTrack {
    
}

final class WRKRTCAudioTrackImpl: WRKRTCAudioTrack {
    
    let audioTrack: RTCAudioTrack
    
    init(_ audioTrack: RTCAudioTrack) {
        self.audioTrack = audioTrack
    }
}
