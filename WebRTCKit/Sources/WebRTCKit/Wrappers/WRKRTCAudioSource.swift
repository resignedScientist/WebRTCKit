import WebRTC

protocol WRKRTCAudioSource: AnyObject {
    
}

class WRKRTCAudioSourceImpl: WRKRTCAudioSource {
    
    let audioSource: RTCAudioSource
    
    init(_ audioSource: RTCAudioSource) {
        self.audioSource = audioSource
    }
}
