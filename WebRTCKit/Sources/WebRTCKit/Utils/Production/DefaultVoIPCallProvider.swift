import AVKit
import CallKit
import WebRTC

final class DefaultVoIPCallProvider: NSObject, VoIPCallProvider {
    
    @Inject(\.webRTCManager) private var webRTCManager
    
    private let provider: CXProvider
    private let callController: WRKCallController
    private let rtcAudioSession: WRKRTCAudioSession
    private var localPeerID: PeerID?
    private var currentCallID: UUID?
    private var startCallHandler: (@Sendable (Error?) -> Void)?
    private var endCallHandler: (@Sendable (Error?) -> Void)?
    private var answerCallHandler: (@Sendable (Error?) -> Void)?
    private var doNotDisturbIsEnabled = false
    
    init(
        provider: CXProvider = {
            let configuration = CXProviderConfiguration()
            configuration.supportsVideo = true
            return CXProvider(configuration: configuration)
        }(),
        callController: WRKCallController = WRKCallControllerImpl(CXCallController()),
        rtcAudioSession: WRKRTCAudioSession = WRKRTCAudioSessionImpl(.sharedInstance())
    ) {
        self.provider = provider
        self.callController = callController
        self.rtcAudioSession = rtcAudioSession
        
        super.init()
        
        provider.setDelegate(self, queue: nil)
    }
    
    func reportIncomingCall(
        uuid: UUID,
        handle: String,
        hasVideo: Bool
    ) async throws {
        
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: handle)
        update.hasVideo = hasVideo
        
        do {
            try await provider.reportNewIncomingCall(
                with: uuid,
                update: update
            )
            doNotDisturbIsEnabled = false
        } catch CXErrorCodeIncomingCallError.filteredByDoNotDisturb {
            print("⚠️ Do not disturb is enabled.")
            doNotDisturbIsEnabled = true
        }
        
        currentCallID = uuid
    }
    
    func startOutgoingCall(
        uuid: UUID,
        handle: String,
        hasVideo: Bool
    ) async throws {
        
        guard startCallHandler == nil else {
            print("⚠️ startOutgoingCall called, but we are already waiting for the call to start.")
            return
        }
        
        defer {
            startCallHandler = nil
        }
        
        let handle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
        startCallAction.isVideo = hasVideo
        
        async let asyncStartCall: Void = try withCheckedThrowingContinuation { [weak self] continuation in
            Task { [weak self] in
                await self?.setStartCallHandler { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
        
        #if targetEnvironment(simulator)
        provider(provider, perform: startCallAction)
        #endif
        
        if doNotDisturbIsEnabled {
            provider(provider, perform: startCallAction)
        } else {
            let transaction = CXTransaction(action: startCallAction)
            try await callController.request(transaction)
            try await asyncStartCall
        }
        
        currentCallID = uuid
    }
    
    func acceptIncomingCall() async throws {
        
        guard let uuid = currentCallID else {
            print("❌ No current call UUID available.")
            return
        }
        
        guard answerCallHandler == nil else {
            print("⚠️ acceptIncomingCall called, but we are already waiting for the answer to be sent.")
            return
        }
        
        defer {
            answerCallHandler = nil
        }
        
        async let asyncAnswerCall: Void = try withCheckedThrowingContinuation { [weak self] continuation in
            Task { [weak self] in
                await self?.setAnswerCallHandler { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
        
        let answerCallAction = CXAnswerCallAction(call: uuid)
        
        #if targetEnvironment(simulator)
        provider(provider, perform: answerCallAction)
        #endif
        
        if doNotDisturbIsEnabled {
            provider(provider, perform: answerCallAction)
        } else {
            let transaction = CXTransaction(action: answerCallAction)
            try await callController.request(transaction)
            try await asyncAnswerCall
        }
    }
    
    func endCall() async throws {
        
        guard let uuid = currentCallID else {
            print("ℹ️ End Call message received, but there is no call running.")
            return
        }
        
        guard endCallHandler == nil else {
            print("⚠️ endCall called, but we are already waiting for the call to end.")
            return
        }
        
        defer {
            endCallHandler = nil
        }
        
        async let asyncEndCall: Void = try withCheckedThrowingContinuation { [weak self] continuation in
            Task { [weak self] in
                await self?.setEndCallHandler { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
        
        let endCallAction = CXEndCallAction(call: uuid)
        
        #if targetEnvironment(simulator)
        provider(provider, perform: endCallAction)
        #endif
        
        if doNotDisturbIsEnabled {
            provider(provider, perform: endCallAction)
        } else {
            let transaction = CXTransaction(action: endCallAction)
            try await callController.request(transaction)
            try await asyncEndCall
        }
        
        currentCallID = nil
    }
}

// MARK: - CXProviderDelegate

extension DefaultVoIPCallProvider: CXProviderDelegate {
    
    nonisolated func providerDidReset(_ provider: CXProvider) {
        print("ℹ️ CXProvider did reset.")
    }
    
    nonisolated func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        
        let peerID = action.handle.value
        
        Task {
            do {
                let localPeerID = try await webRTCManager.setup()
                await setLocalPeerID(localPeerID)
                try await webRTCManager.startVideoCall(to: peerID)
                action.fulfill()
                await startCallHandler?(nil)
            } catch {
                print("⚠️ Start Call Action failed - \(error)")
                action.fail()
                await startCallHandler?(error)
            }
        }
    }
    
    nonisolated func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        Task {
            do {
                try await webRTCManager.answerCall()
                action.fulfill()
                await answerCallHandler?(nil)
            } catch {
                print("⚠️ Answer Call Action failed - \(error)")
                action.fail()
                await answerCallHandler?(error)
            }
        }
    }
    
    nonisolated func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        Task {
#if targetEnvironment(simulator)
            guard let endCallHandler = await endCallHandler else {
                action.fulfill()
                return
            }
            do {
                try await webRTCManager.stopVideoCall()
                action.fulfill()
                endCallHandler(nil)
            } catch {
                print("⚠️ End Call Action failed - \(error)")
                action.fail()
                endCallHandler(error)
            }
#else
            do {
                try await webRTCManager.stopVideoCall()
                action.fulfill()
                await endCallHandler?(nil)
            } catch {
                print("⚠️ End Call Action failed - \(error)")
                action.fail()
                await endCallHandler?(error)
            }
#endif
        }
    }
    
    nonisolated func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("ℹ️ VoIPCallProvider - Audio Session Activated")
        activateAudioSession()
    }
    
    nonisolated func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("ℹ️ VoIPCallProvider - Audio Session Deactivated")
        deactivateAudioSession()
    }
}

// MARK: - Private functions

private extension DefaultVoIPCallProvider {
    
    func setStartCallHandler(_ startCallHandler: @escaping @Sendable (Error?) -> Void) {
        self.startCallHandler = startCallHandler
    }
    
    func setAnswerCallHandler(_ answerCallHandler: @escaping @Sendable (Error?) -> Void) {
        self.answerCallHandler = answerCallHandler
    }
    
    func setEndCallHandler(_ endCallHandler: @escaping @Sendable (Error?) -> Void) {
        self.endCallHandler = endCallHandler
    }
    
    func setLocalPeerID(_ localPeerID: PeerID) {
        self.localPeerID = localPeerID
    }
    
    nonisolated func activateAudioSession() {
        setupAudioConfiguration()
        setAudioSessionActive(true)
    }
    
    nonisolated func deactivateAudioSession() {
        resetAudioConfiguration()
        setAudioSessionActive(false)
    }
    
    nonisolated func setupAudioConfiguration() {
        rtcAudioSession.lockForConfiguration()
        
        let configuration = RTCAudioSessionConfiguration.webRTC()
        configuration.categoryOptions = [
            .allowBluetooth,
            .allowBluetoothA2DP,
            .allowAirPlay,
            .defaultToSpeaker,
            .duckOthers
        ]
        
        do {
            try rtcAudioSession.setConfiguration(configuration)
        } catch {
            print("⚠️ VoIPCallProvider - Failed to configure audio session: \(error)")
        }
        
        rtcAudioSession.unlockForConfiguration()
    }
    
    nonisolated func resetAudioConfiguration() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
        } catch {
            print("⚠️ VoIPCallProvider - Failed to reset audio configuration: \(error)")
        }
    }
    
    nonisolated func setAudioSessionActive(_ active: Bool) {
        rtcAudioSession.lockForConfiguration()
        do {
            try rtcAudioSession.setActive(active)
            rtcAudioSession.isAudioEnabled = active
        } catch {
            print("⚠️ VoIPCallProvider - Failed to set audio session active (\(active)): \(error)")
        }
        rtcAudioSession.unlockForConfiguration()
    }
}
