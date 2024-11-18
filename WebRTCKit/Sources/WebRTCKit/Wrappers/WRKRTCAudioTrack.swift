import WebRTC

public protocol WRKRTCAudioTrack: AnyObject, WRKRTCMediaStreamTrack {
    
}

final class WRKRTCAudioTrackImpl: WRKRTCAudioTrack, @unchecked Sendable {
    
    private let _audioTrack: RTCAudioTrack
    private let queue = DispatchQueue(label: "com.webrtckit.WRKRTCAudioTrack")
    
    var audioTrack: RTCAudioTrack {
        queue.sync {
            _audioTrack
        }
    }
    
    init(_ audioTrack: RTCAudioTrack) {
        self._audioTrack = audioTrack
    }
}
