import WebRTC

protocol WRKRTCAudioSession: AnyObject, Sendable {
    
    /** This property is only effective if useManualAudio is YES.
     *  Represents permission for WebRTC to initialize the VoIP audio unit.
     *  When set to NO, if the VoIP audio unit used by WebRTC is active, it will be
     *  stopped and uninitialized. This will stop incoming and outgoing audio.
     *  When set to YES, WebRTC will initialize and start the audio unit when it is
     *  needed (e.g. due to establishing an audio connection).
     *  This property was introduced to work around an issue where if an AVPlayer is
     *  playing audio while the VoIP audio unit is initialized, its audio would be
     *  either cut off completely or played at a reduced volume. By preventing
     *  the audio unit from being initialized until after the audio has completed,
     *  we are able to prevent the abrupt cutoff.
     */
    var isAudioEnabled: Bool { get set }
    
    /** If YES, WebRTC will not initialize the audio unit automatically when an
     *  audio track is ready for playout or recording. Instead, applications should
     *  call setIsAudioEnabled. If NO, WebRTC will initialize the audio unit
     *  as soon as an audio track is ready for playout or recording.
     */
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
    
    /// If `active`, activates the audio session if it isn't already active.
    /// Successful calls must be balanced with a setActive:NO when activation is no
    /// longer required. If not `active`, deactivates the audio session if one is
    /// active and this is the last balanced call. When deactivating, the
    /// AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation option is passed to
    /// AVAudioSession.
    func setActive(_ active: Bool) throws
    
    /// Applies the configuration to the current session. Attempts to set all
    /// properties even if previous ones fail. Only the last error will be
    /// returned.
    /// `lockForConfiguration` must be called first.
    func setConfiguration(_ configuration: RTCAudioSessionConfiguration) throws
}

final class WRKRTCAudioSessionImpl: WRKRTCAudioSession, @unchecked Sendable {
    
    private let _audioSession: RTCAudioSession
    private let queue = DispatchQueue(label: "com.webrtckit.WRKRTCAudioSession")
    
    var audioSession: RTCAudioSession {
        queue.sync {
            _audioSession
        }
    }
    
    var isAudioEnabled: Bool {
        get {
            queue.sync {
                _audioSession.isAudioEnabled
            }
        }
        set {
            queue.sync {
                _audioSession.isAudioEnabled = newValue
            }
        }
    }
    
    var useManualAudio: Bool {
        get {
            queue.sync {
                _audioSession.useManualAudio
            }
        }
        set {
            queue.sync {
                _audioSession.useManualAudio = newValue
            }
        }
    }
    
    init(_ audioSession: RTCAudioSession) {
        self._audioSession = audioSession
    }
    
    func audioSessionDidActivate(_ session: any WRKAVAudioSession) {
        queue.sync {
            if let session = (session as? WRKAVAudioSessionImpl)?.audioSession {
                _audioSession.audioSessionDidActivate(session)
            }
        }
    }
    
    func audioSessionDidDeactivate(_ session: any WRKAVAudioSession) {
        queue.sync {
            if let session = (session as? WRKAVAudioSessionImpl)?.audioSession {
                _audioSession.audioSessionDidDeactivate(session)
            }
        }
    }
    
    func lockForConfiguration() {
        queue.sync {
            _audioSession.lockForConfiguration()
        }
    }
    
    func unlockForConfiguration() {
        queue.sync {
            _audioSession.unlockForConfiguration()
        }
    }
    
    func setActive(_ active: Bool) throws {
        try queue.sync {
            try _audioSession.setActive(active)
        }
    }
    
    func setConfiguration(_ configuration: RTCAudioSessionConfiguration) throws {
        try queue.sync {
            try _audioSession.setConfiguration(configuration)
        }
    }
}
