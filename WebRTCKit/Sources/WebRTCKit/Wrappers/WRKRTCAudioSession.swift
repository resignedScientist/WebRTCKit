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
    func audioSessionDidActivate(_ session: WRKAVAudioSession) async
    
    /// Called when the audio session is deactivated outside of the app by iOS.
    func audioSessionDidDeactivate(_ session: WRKAVAudioSession) async
    
    func perform(_ action: @escaping @Sendable (_ audioSession: RTCAudioSession) -> Void)
}

final class WRKRTCAudioSessionImpl: WRKRTCAudioSession, @unchecked Sendable {
    
    private let _audioSession: RTCAudioSession
    private let queue = DispatchSerialQueue(label: "AudioSessionQueue")
    
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
    
    func audioSessionDidActivate(_ session: any WRKAVAudioSession) async {
        return await withCheckedContinuation { continuation in
            queue.async {
                if let session = (session as? WRKAVAudioSessionImpl)?.audioSession {
                    self._audioSession.audioSessionDidActivate(session)
                }
                continuation.resume()
            }
        }
    }
    
    func audioSessionDidDeactivate(_ session: any WRKAVAudioSession) async {
        return await withCheckedContinuation { continuation in
            queue.async {
                if let session = (session as? WRKAVAudioSessionImpl)?.audioSession {
                    self._audioSession.audioSessionDidDeactivate(session)
                }
                continuation.resume()
            }
        }
    }
    
    func perform(_ action: @escaping @Sendable (_ audioSession: RTCAudioSession) -> Void) {
        queue.async {
            action(self._audioSession)
        }
    }
}
