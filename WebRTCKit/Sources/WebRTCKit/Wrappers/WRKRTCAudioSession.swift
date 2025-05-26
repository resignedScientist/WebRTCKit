import WebRTC

@WebRTCActor
protocol WRKRTCAudioSession: AnyObject, Sendable {
    
    /// This property is only effective if useManualAudio is YES.
    /// Represents permission for WebRTC to initialize the VoIP audio unit.
    /// When set to NO, if the VoIP audio unit used by WebRTC is active, it will be
    /// stopped and uninitialized. This will stop incoming and outgoing audio.
    /// When set to YES, WebRTC will initialize and start the audio unit when it is
    /// needed (e.g. due to establishing an audio connection).
    /// This property was introduced to work around an issue where if an AVPlayer is
    /// playing audio while the VoIP audio unit is initialized, its audio would be
    /// either cut off completely or played at a reduced volume. By preventing
    /// the audio unit from being initialized until after the audio has completed,
    /// we are able to prevent the abrupt cutoff.
    var isAudioEnabled: Bool { get set }
    
    /// If YES, WebRTC will not initialize the audio unit automatically when an
    /// audio track is ready for playout or recording. Instead, applications should
    /// call setIsAudioEnabled. If NO, WebRTC will initialize the audio unit
    /// as soon as an audio track is ready for playout or recording.
    var useManualAudio: Bool { get set }
    
    /// Called when the audio session is activated outside of the app by iOS.
    func audioSessionDidActivate(_ session: WRKAVAudioSession)
    
    /// Called when the audio session is deactivated outside of the app by iOS.
    func audioSessionDidDeactivate(_ session: WRKAVAudioSession)
    
    /// Request exclusive access to the audio session for configuration. This call
    /// will block if the lock is held by another object.
    func lockForConfiguration()
    
    /// Relinquishes exclusive access to the audio session.
    func unlockForConfiguration()
    
    /// Applies the configuration to the current session. Attempts to set all
    /// properties even if previous ones fail. Only the last error will be
    /// returned.
    /// `lockForConfiguration` must be called first.
    func setConfiguration(_ configuration: RTCAudioSessionConfiguration) throws
    
    /// Request exclusive access to the audio session for configuration. This call
    /// will block if the lock is held by another object.
    func setActive(_ active: Bool) throws
    
    /// Adds a delegate, which is held weakly.
    func add(_ delegate: WRKRTCAudioSessionDelegate)
    
    func overrideOutputAudioPort(_ portOverride: AVAudioSession.PortOverride) throws
}

final class WRKRTCAudioSessionImpl: NSObject, WRKRTCAudioSession {
    
    private let _audioSession: RTCAudioSession
    private weak var delegate: WRKRTCAudioSessionDelegate?
    
    var isAudioEnabled: Bool {
        get {
            _audioSession.isAudioEnabled
        }
        set {
            _audioSession.isAudioEnabled = newValue
        }
    }
    
    var useManualAudio: Bool {
        get {
            _audioSession.useManualAudio
        }
        set {
            _audioSession.useManualAudio = newValue
        }
    }
    
    init(_ audioSession: RTCAudioSession) {
        _audioSession = audioSession
        super.init()
        audioSession.add(self)
    }
    
    func audioSessionDidActivate(_ session: any WRKAVAudioSession) {
        if let session = (session as? WRKAVAudioSessionImpl)?.audioSession {
            _audioSession.audioSessionDidActivate(session)
        }
    }
    
    func audioSessionDidDeactivate(_ session: any WRKAVAudioSession) {
        if let session = (session as? WRKAVAudioSessionImpl)?.audioSession {
            _audioSession.audioSessionDidDeactivate(session)
        }
    }
    
    func lockForConfiguration() {
        _audioSession.lockForConfiguration()
    }
    
    func unlockForConfiguration() {
        _audioSession.unlockForConfiguration()
    }
    
    func setConfiguration(_ configuration: RTCAudioSessionConfiguration) throws {
        try _audioSession.setConfiguration(configuration)
    }
    
    func setActive(_ active: Bool) throws {
        try _audioSession.setActive(active)
    }
    
    func add(_ delegate: WRKRTCAudioSessionDelegate) {
        self.delegate = delegate
    }
    
    func overrideOutputAudioPort(_ portOverride: AVAudioSession.PortOverride) throws {
        try _audioSession.overrideOutputAudioPort(portOverride)
    }
}

// MARK: - RTCAudioSessionDelegate

extension WRKRTCAudioSessionImpl: RTCAudioSessionDelegate {
    
    nonisolated func audioSession(_ audioSession: RTCAudioSession, didSetActive active: Bool) {
        Task { @WebRTCActor in
            delegate?.audioSessionDidSetActive(self, active: active)
        }
    }
}
