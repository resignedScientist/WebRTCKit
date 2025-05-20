import AVKit
import CallKit
import WebRTC

enum CallProviderError: Error {
    
    /// Thrown if multiple calls are being reported as we only allow one single call at a time.
    case multipleReportedCalls
}

final class DefaultVoIPCallProvider: NSObject, VoIPCallProvider {
    
    @Inject(\.webRTCManager) private var webRTCManager
    @Inject(\.callManager) private var callManager
    @Inject(\.config.manualAudioMode) private var manualAudioMode
    
    private let provider: WRKCXProvider
    private let callController: WRKCallController
    private let rtcAudioSession: WRKRTCAudioSession
    private let log = Logger(caller: "VoIPCallProvider")
    
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
        
        // prevent receiving another call if a call is already created.
        guard currentCallID == nil else {
            throw CallProviderError.multipleReportedCalls
        }
        
        log.info("Incoming call reported from \(handle)")
        
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
            log.info("Do not disturb is enabled.")
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
            log.fault("startOutgoingCall called, but we are already waiting for the call to start.")
            return
        }
        
        defer {
            startCallHandler = nil
        }
        
        log.info("Starting outgoing call to \(handle)…")
        
        let handle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
        startCallAction.isVideo = hasVideo
        
        #if targetEnvironment(simulator)
        await provider(
            provider,
            perform: StartCallAction(from: startCallAction)
        )
        #else
        if doNotDisturbIsEnabled {
            await provider(
                provider,
                perform: StartCallAction(from: startCallAction)
            )
        } else {
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
            let transaction = CXTransaction(action: startCallAction)
            try await callController.request(transaction)
            try await asyncStartCall
        }
        #endif
        
        currentCallID = uuid
    }
    
    func acceptIncomingCall() async throws {
        
        guard let uuid = currentCallID else {
            log.fault("No current call UUID available.")
            return
        }
        
        guard answerCallHandler == nil else {
            log.fault("acceptIncomingCall called, but we are already waiting for the answer to be sent.")
            return
        }
        
        defer {
            answerCallHandler = nil
        }
        
        log.info("Accepting incoming call…")
        
        let answerCallAction = CXAnswerCallAction(call: uuid)
        
        #if targetEnvironment(simulator)
        await provider(
            provider,
            perform: AnswerCallAction(from: answerCallAction)
        )
        #else
        if doNotDisturbIsEnabled {
            await provider(
                provider,
                perform: AnswerCallAction(from: answerCallAction)
            )
        } else {
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
            let transaction = CXTransaction(action: answerCallAction)
            try await callController.request(transaction)
            try await asyncAnswerCall
        }
        #endif
    }
    
    func endCall() async throws {
        
        guard let uuid = currentCallID else {
            log.error("End Call message received, but there is no call running.")
            return
        }
        
        guard endCallHandler == nil, !isEndingCall else {
            log.error("endCall called, but we are already waiting for the call to end.")
            return
        }
        
        log.info("Ending call…")
        
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
        log.info("CXProvider did reset.")
    }
    
    func provider(_ provider: WRKCXProvider, perform action: StartCallAction) async {
        log.info("Start call action received.")
        
        let peerID = action.handle.value
        do {
            let localPeerID = try await webRTCManager.setup()
            setLocalPeerID(localPeerID)
            try await webRTCManager.startVideoCall(to: peerID)
            action.fulfill()
            startCallHandler?(nil)
        } catch {
            log.error("Start Call Action failed - \(error)")
            action.fail()
            startCallHandler?(error)
        }
    }
    
    func provider(_ provider: WRKCXProvider, perform action: AnswerCallAction) async {
        log.info("Answer call action received.")
        
        do {
            try await webRTCManager.answerCall()
            action.fulfill()
            answerCallHandler?(nil)
        } catch {
            log.error("Answer Call Action failed - \(error)")
            action.fail()
            answerCallHandler?(error)
        }
    }
    
    func provider(_ provider: WRKCXProvider, perform action: EndCallAction) async {
        
        // For some reason on simulators & on mac catalyst (designed for iPad),
        // the end call action is called immediately after accepting a call.
        // Maybe because of no CallKit support there?
        let isSimulator: Bool = {
            #if targetEnvironment(simulator)
            return true
            #else
            return false
            #endif
        }()
        let isMacCatalyst = ProcessInfo.processInfo.isiOSAppOnMac
        
        // So on these platforms, we only allow ending calls if the actual button in the app was pressed.
        if isSimulator || isMacCatalyst {
            guard isEndingCall else { return }
        }
        
        log.info("End call action received.")
        
        do {
            try await webRTCManager.stopVideoCall()
            action.fulfill()
            endCallHandler?(nil)
        } catch {
            log.error("End Call Action failed - \(error)")
            action.fail()
            endCallHandler?(error)
        }
    }
    
    func provider(_ provider: WRKCXProvider, didActivate audioSession: AVAudioSession) async {
        if manualAudioMode {
            log.info("Should activate audio session")
            callManager.shouldActivateAudioSession()
        } else {
            log.info("Activating audio session…")
            await activateAudioSession()
        }
    }
    
    func provider(_ provider: WRKCXProvider, didDeactivate audioSession: AVAudioSession) async {
        if (manualAudioMode) {
            log.info("Should deactivate audio session")
            callManager.shouldDeactivateAudioSession()
        } else {
            log.info("Deactivating audio session…")
            await deactivateAudioSession()
        }
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
        return await withCheckedContinuation { [log] continuation in
            rtcAudioSession.perform { audioSession in
                audioSession.lockForConfiguration()
                
                let configuration = RTCAudioSessionConfiguration.webRTC()
                configuration.categoryOptions = [
                    .allowBluetooth,
                    .allowBluetoothA2DP,
                    .allowAirPlay,
                    .defaultToSpeaker,
                    .duckOthers
                ]
                
                do {
                    try audioSession.setConfiguration(configuration)
                    try audioSession.overrideOutputAudioPort(.speaker)
                    log.info("Successfully configured audio session.")
                } catch {
                    log.error("Failed to configure audio session: \(error)")
                }
                
                audioSession.unlockForConfiguration()
                continuation.resume()
            }
        }
    }
    
    nonisolated func resetAudioConfiguration() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try audioSession.overrideOutputAudioPort(.none)
            log.info("Successfully reset audio configuration.")
        } catch {
            log.error("Failed to reset audio configuration: \(error)")
        }
    }
    
    nonisolated func setAudioSessionActive(_ active: Bool) async {
        return await withCheckedContinuation { [log, active] continuation in
            rtcAudioSession.perform { audioSession in
                audioSession.lockForConfiguration()
                
                do {
                    try audioSession.setActive(active)
                    audioSession.isAudioEnabled = active
                    if active {
                        log.info("Successfully activated audio session.")
                    } else {
                        log.info("Successfully deactivated audio session.")
                    }
                } catch {
                    log.error("Failed to set audio session active (\(active)): \(error)")
                }
                
                audioSession.unlockForConfiguration()
                continuation.resume()
            }
        }
    }
}
