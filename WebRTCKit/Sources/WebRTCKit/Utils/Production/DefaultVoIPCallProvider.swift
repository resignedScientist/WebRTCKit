import AVKit
import CallKit
import WebRTC

final class DefaultVoIPCallProvider: NSObject, VoIPCallProvider {
    
    @Inject(\.webRTCManager) private var webRTCManager
    
    private let provider: WRKCXProvider
    private let callController: WRKCallController
    private let rtcAudioSession: WRKRTCAudioSession
    private var localPeerID: PeerID?
    private var currentCallID: UUID?
    private var startCallHandler: (@Sendable (Error?) -> Void)?
    private var endCallHandler: (@Sendable (Error?) -> Void)?
    private var answerCallHandler: (@Sendable (Error?) -> Void)?
    private var doNotDisturbIsEnabled = false
    private var isEndingCall = false
    
    init(
        provider: WRKCXProvider = {
            let configuration = CXProviderConfiguration()
            configuration.supportsVideo = true
            return WRKCXProvider(configuration: configuration)
        }(),
        callController: WRKCallController = WRKCallControllerImpl(CXCallController()),
        rtcAudioSession: WRKRTCAudioSession = WRKRTCAudioSessionImpl(.sharedInstance())
    ) {
        self.provider = provider
        self.callController = callController
        self.rtcAudioSession = rtcAudioSession
        
        super.init()
        
        provider.setDelegate(self)
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
        await provider(
            provider,
            perform: StartCallAction(from: startCallAction)
        )
        #endif
        
        if doNotDisturbIsEnabled {
            await provider(
                provider,
                perform: StartCallAction(from: startCallAction)
            )
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
        await provider(
            provider,
            perform: AnswerCallAction(from: answerCallAction)
        )
        #endif
        
        if doNotDisturbIsEnabled {
            await provider(
                provider,
                perform: AnswerCallAction(from: answerCallAction)
            )
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
        
        guard endCallHandler == nil, !isEndingCall else {
            print("⚠️ endCall called, but we are already waiting for the call to end.")
            return
        }
        
        isEndingCall = true
        
        defer {
            endCallHandler = nil
            currentCallID = nil
            isEndingCall = false
        }
        
        let endCallAction = CXEndCallAction(call: uuid)
        
        #if targetEnvironment(simulator)
        await provider(
            provider,
            perform: EndCallAction(from: endCallAction)
        )
        #else
        if doNotDisturbIsEnabled {
            await provider(
                provider,
                perform: EndCallAction(from: endCallAction)
            )
        } else {
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
            let transaction = CXTransaction(action: endCallAction)
            try await callController.request(transaction)
            try await asyncEndCall
        }
        #endif
    }
}

// MARK: - CXProviderDelegate

extension DefaultVoIPCallProvider: CallProviderDelegate {
    
    func providerDidReset(_ provider: WRKCXProvider) async {
        print("ℹ️ CXProvider did reset.")
    }
    
    func provider(_ provider: WRKCXProvider, perform action: StartCallAction) async {
        let peerID = action.handle.value
        do {
            let localPeerID = try await webRTCManager.setup()
            setLocalPeerID(localPeerID)
            try await webRTCManager.startVideoCall(to: peerID)
            action.fulfill()
            startCallHandler?(nil)
        } catch {
            print("⚠️ Start Call Action failed - \(error)")
            action.fail()
            startCallHandler?(error)
        }
    }
    
    func provider(_ provider: WRKCXProvider, perform action: AnswerCallAction) async {
        do {
            try await webRTCManager.answerCall()
            action.fulfill()
            answerCallHandler?(nil)
        } catch {
            print("⚠️ Answer Call Action failed - \(error)")
            action.fail()
            answerCallHandler?(error)
        }
    }
    
    func provider(_ provider: WRKCXProvider, perform action: EndCallAction) async {
        
        // For some reason on simulators, the end call action is called immediately
        // after accepting a call. Maybe because of no CallKit support there?
        #if targetEnvironment(simulator)
        guard isEndingCall else { return }
        #endif
        
        do {
            try await webRTCManager.stopVideoCall()
            action.fulfill()
            endCallHandler?(nil)
        } catch {
            print("⚠️ End Call Action failed - \(error)")
            action.fail()
            endCallHandler?(error)
        }
    }
    
    func provider(_ provider: WRKCXProvider, didActivate audioSession: AVAudioSession) async {
        print("ℹ️ VoIPCallProvider - Audio Session Activated")
        await activateAudioSession()
    }
    
    func provider(_ provider: WRKCXProvider, didDeactivate audioSession: AVAudioSession) async {
        print("ℹ️ VoIPCallProvider - Audio Session Deactivated")
        await deactivateAudioSession()
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
    
    nonisolated func activateAudioSession() async {
        await setupAudioConfiguration()
        await setAudioSessionActive(true)
    }
    
    nonisolated func deactivateAudioSession() async {
        resetAudioConfiguration()
        await setAudioSessionActive(false)
    }
    
    nonisolated func setupAudioConfiguration() async {
        await rtcAudioSession.lockForConfiguration()
        
        let configuration = RTCAudioSessionConfiguration.webRTC()
        configuration.categoryOptions = [
            .allowBluetooth,
            .allowBluetoothA2DP,
            .allowAirPlay,
            .defaultToSpeaker,
            .duckOthers
        ]
        
        do {
            try await rtcAudioSession.setConfiguration(configuration)
        } catch {
            print("⚠️ VoIPCallProvider - Failed to configure audio session: \(error)")
        }
        
        await rtcAudioSession.unlockForConfiguration()
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
    
    nonisolated func setAudioSessionActive(_ active: Bool) async {
        await rtcAudioSession.lockForConfiguration()
        do {
            try await rtcAudioSession.setActive(active)
            rtcAudioSession.isAudioEnabled = active
        } catch {
            print("⚠️ VoIPCallProvider - Failed to set audio session active (\(active)): \(error)")
        }
        await rtcAudioSession.unlockForConfiguration()
    }
}
