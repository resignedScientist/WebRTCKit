import AVKit

protocol WRKAVAudioSession: AnyObject, Sendable {
    
    func setActive(_ active: Bool) throws
    
    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws
}

final class WRKAVAudioSessionImpl: WRKAVAudioSession {
    
    let audioSession: AVAudioSession
    
    init(_ audioSession: AVAudioSession) {
        self.audioSession = audioSession
    }
    
    func setActive(_ active: Bool) throws {
        try audioSession.setActive(active)
    }
    
    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws {
        try audioSession.setCategory(
            category,
            mode: mode,
            options: options
        )
    }
}
