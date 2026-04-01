import WebRTC

public typealias PeerID = String

@MainActor
public struct WebRTCKit {
    
    /// Initialize the WebRTCKit for production.
    ///  
    /// - Parameters:
    ///   - signalingServer: A reference to the signaling server connection to use.
    ///   - audioSessionConfigurator: A reference to a class that configures the audio session.
    ///   - config: The configuration settings to apply.
    ///   - enableVerboseLogging: A Boolean value that determines wether verbose logging for WebRTC is enabled.
    ///   - audioDevice: An optional audio device to use.
    ///   - logLevel: The log level for our logger; defaults to only log errors.
    ///   - loggerDelegate: A delegate for the logger that receives all the logs.
    ///   - pushPayloadParser: A reference to a class that parses the VoIP push payload.
    /// - Returns: The controller to interact with the WebRTCKit.
    public static func initialize(
        signalingServer: SignalingServerConnection,
        audioSessionConfigurator: AudioSessionConfigurator,
        config: Config,
        audioDevice: RTCAudioDevice? = nil,
        logLevel: LogLevel = .error,
        loggerDelegate: LoggerDelegate? = nil,
        pushPayloadParser: PushPayloadParser? = nil
    ) async -> WebRTCController {
        
        let webRTCManager: WebRTCManager = DefaultWebRTCManager(
            factory: WRKRTCPeerConnectionFactoryImpl(
                audioDevice: audioDevice
            )
        )
        let callEstablisher: CallEstablisher = CallEstablisherImpl(
            webRTCManager: webRTCManager
        )
        let callManager: CallManager = CallManagerImpl(
            callEstablisher: callEstablisher
        )
        let providerDelegate = ProviderDelegateImpl(
            callManager: callManager,
            audioSessionConfigurator: audioSessionConfigurator
        )
        let pushCredentialStore = PushCredentialStore()
        
        let container = DIContainer.create(
            config: config,
            webRTCManager: webRTCManager,
            pushHandler: DefaultVoIPPushHandler(
                store: pushCredentialStore,
                parser: pushPayloadParser ?? DefaultPushPayloadParser()
            ),
            pushCredentialProvider: pushCredentialStore,
            signalingServer: signalingServer,
            networkMonitor: DefaultNetworkMonitor(),
            logLevel: logLevel,
            loggerDelegate: loggerDelegate,
            callManager: callManager,
            providerDelegate: providerDelegate
        )
        
        if logLevel == .verbose {
            RTCSetMinDebugLogLevel(.verbose)
        }
        
        await container.setup()
        
        return WebRTCControllerImpl(container: container)
    }
    
    /// Initialize the framework for testing or previews using mock classes.
    public static func initializeForTesting() -> WebRTCController {
        
        let callManager = CallManagerImpl(
            callEstablisher: DummyCallEstablisher()
        )
        
        let pushCredentialStore = PushCredentialStore()
        let container = DIContainer.create(
            config: .preview,
            webRTCManager: PreviewWebRTCManager(),
            pushHandler: PreviewVoIPPushHandler(),
            pushCredentialProvider: pushCredentialStore,
            signalingServer: PreviewSignalingServerConnection(),
            networkMonitor: PreviewNetworkMonitor(),
            logLevel: .debug,
            loggerDelegate: nil,
            callManager: CallManagerImpl(
                callEstablisher: DummyCallEstablisher()
            ),
            providerDelegate: ProviderDelegateImpl(
                callManager: callManager,
                audioSessionConfigurator: MockAudioSessionConfigurator()
            )
        )
        
        return WebRTCControllerImpl(container: container)
    }
    
    // for unit tests
    static func initialize(
        config: Config,
        webRTCManager: WebRTCManager,
        pushHandler: VoIPPushHandler,
        pushCredentialProvider: PushCredentialProviding,
        signalingServer: SignalingServerConnection,
        networkMonitor: NetworkMonitor,
        callManager: CallManager,
        providerDelegate: ProviderDelegate
    ) async -> WebRTCController {
        
        let container = DIContainer.create(
            config: config,
            webRTCManager: webRTCManager,
            pushHandler: pushHandler,
            pushCredentialProvider: pushCredentialProvider,
            signalingServer: signalingServer,
            networkMonitor: networkMonitor,
            logLevel: .debug,
            loggerDelegate: nil,
            callManager: callManager,
            providerDelegate: providerDelegate
        )
        
        await container.setup()
        
        return WebRTCControllerImpl(container: container)
    }
}

/// An object to interact with the WebRTCKit.
@MainActor
public protocol WebRTCController: AnyObject, Sendable {
    
    var voipPushHandler: VoIPPushHandler { get }
    
    var pushCredentialProvider: PushCredentialProviding { get }
    
    /// Sets the delegate to handle WebRTC data channel events.
    /// - Parameter delegate: A delegate conforming to `WebRTCKitDataChannelDelegate`.
    func setDataChannelDelegate(_ dataChannelDelegate: WebRTCKitDataChannelDelegate?)
    
    /// Sets the delegate to handle WebRTC video track events.
    /// - Parameter delegate: A delegate conforming to `WebRTCKitVideoTrackDelegate`.
    func setVideoTrackDelegate(_ videoTrackDelegate: WebRTCKitVideoTrackDelegate?)
    
    /// Sets the delegate to handle WebRTC audio track events.
    /// - Parameter delegate: A delegate conforming to `WebRTCKitAudioTrackDelegate`.
    func setAudioTrackDelegate(_ audioTrackDelegate: WebRTCKitAudioTrackDelegate?)
    
    /// Sets the delegate to handle WebRTC errors.
    /// - Parameter delegate: A delegate conforming to `WebRTCKitErrorDelegate`.
    func setErrorDelegate(_ errorDelegate: WebRTCKitErrorDelegate?)
    
    /// Sets the delegate to handle call state changes.
    /// - Parameter delegate: A delegate conforming to `WebRTCKitCallStateDelegate`.
    func setCallStateDelegate(_ callStateDelegate: WebRTCKitCallStateDelegate?)
    
    /// Set the initial data channels that will be added before first negotiation.
    ///
    /// They will only be added if we are the initiator of the call.
    /// - Parameter dataChannels: The initial data channels.
    func setInitialDataChannels(_ dataChannels: [DataChannelSetup])
    
    /// Enables video initially before first negotiation,
    /// so that no re-negotiation is necessary to enable it.
    /// - Parameters:
    ///   - enabled: Should video be enabled initially?
    ///   - imageSize: The image size of the local video.
    ///   - videoCapturer: An optional capturer to use.
    func setInitialVideoEnabled(enabled: Bool, imageSize: CGSize, videoCapturer: RTCVideoCapturer) async
    
    /// Enables video initially before first negotiation,
    /// so that no re-negotiation is necessary to enable it.
    /// - Parameters:
    ///   - enabled: Should video be enabled initially?
    func setInitialVideoEnabled(enabled: Bool) async
    
    /// Connect to the signaling server and prepares the peer connection.
    /// - Returns: The ID of the local peer.
    func setupConnection() async throws -> PeerID
    
    /// Start the local recording of video.
    /// 
    /// - Parameter videoCapturer: A custom video capturer.
    /// - Parameter imageSize: The size of the image that will be captured.
    func startVideoRecording(videoCapturer: RTCVideoCapturer, imageSize: CGSize) async throws
    
    /// Manual audio mode only; Call this after the audio session was configured.
    /// Tells the manager that the audio track can be added to the call.
    func startAudioRecording() async throws
    
    /// Start the local recording of audio & video streams using the default video capturer.
    func startVideoRecording() async throws
    
    /// Stop the local video recording by removing the local video track & stopping the video capturer.
    func stopVideoRecording() async
    
    /// Was a video track added by calling `startVideoRecording`?
    func isVideoRecording() -> Bool
    
    /// Update the size of the image that we receive as input.
    ///
    /// This will be used for scaling and is only really needed if the image size changes at runtime.
    /// - Parameter imageSize: The new image size.
    func updateImageSize(_ imageSize: CGSize) async
    
    /// Creates a data channel with the given configuration.
    /// - Parameters:
    ///   - setup: The configuration of the data channel.
    /// - Throws: Throws `WebRTCManagerError` on failure.
    func createDataChannel(setup: DataChannelSetup) async throws
    
    /// Start the configuration of things like data channels and other parameters.
    /// While doing the configuration, there is no re-negotiation happening.
    func startConfiguration() async throws
    
    /// Finish the configuration. After calling it, the re-negotiation is happening.
    func commitConfiguration() async throws
    
    /// Initialize a call with another peer.
    /// 
    /// - Parameter peerID: The ID of the remote peer.
    /// - Returns: The UUID of the starting call.
    func sendCallRequest(to peerID: PeerID) async throws -> UUID
    
    /// Accept the incoming call request.
    /// - Parameter callUUID: The UUID of the call to accept.
    func acceptIncomingCall(_ callUUID: UUID) async throws
    
    /// End the call.
    /// - Parameter callUUID: The UUID of the call to end.
    func endCall(_ callUUID: UUID) async throws
    
    /// End the call and disconnect from the signaling server.
    func disconnect() async throws
}

final class WebRTCControllerImpl: WebRTCController {
    
    private let container: DIContainer
    
    var voipPushHandler: VoIPPushHandler { container.pushHandler }
    var pushCredentialProvider: PushCredentialProviding { container.pushCredentialProvider }
    
    init(container: DIContainer) {
        self.container = container
    }
    
    func setDataChannelDelegate(_ dataChannelDelegate: WebRTCKitDataChannelDelegate?) {
        container.webRTCManager.setDataChannelDelegate(dataChannelDelegate)
    }
    
    func setVideoTrackDelegate(_ videoTrackDelegate: WebRTCKitVideoTrackDelegate?) {
        container.webRTCManager.setVideoTrackDelegate(videoTrackDelegate)
    }
    
    func setAudioTrackDelegate(_ audioTrackDelegate: WebRTCKitAudioTrackDelegate?) {
        container.webRTCManager.setAudioTrackDelegate(audioTrackDelegate)
    }
    
    func setErrorDelegate(_ errorDelegate: WebRTCKitErrorDelegate?) {
        container.webRTCManager.setErrorDelegate(errorDelegate)
    }
    
    func setCallStateDelegate(_ callStateDelegate: WebRTCKitCallStateDelegate?) {
        container.callManager.setCallStateDelegate(callStateDelegate)
    }
    
    func setInitialDataChannels(_ dataChannels: [DataChannelSetup]) {
        container.webRTCManager.setInitialDataChannels(dataChannels)
    }
    
    func setInitialVideoEnabled(enabled: Bool) async {
        await container.webRTCManager.setInitialVideoEnabled(
            enabled: enabled,
            imageSize: .zero, // not needed when using default video capturer
            videoCapturer: nil
        )
    }
    
    func setInitialVideoEnabled(
        enabled: Bool,
        imageSize: CGSize,
        videoCapturer: RTCVideoCapturer
    ) async {
        await container.webRTCManager.setInitialVideoEnabled(
            enabled: enabled,
            imageSize: imageSize,
            videoCapturer: VideoCapturer(videoCapturer)
        )
    }
    
    func setupConnection() async throws -> PeerID {
        
        // Start the network monitor to properly handle re-connections to the network.
        await container.networkMonitor.startMonitoring()
        
        return try await container.webRTCManager.setup()
    }
    
    func startAudioRecording() async throws {
        try await container.webRTCManager.startAudioRecording()
    }
    
    func startVideoRecording(videoCapturer: RTCVideoCapturer, imageSize: CGSize) async throws {
        try await container.webRTCManager.startVideoRecording(
            videoCapturer: VideoCapturer(videoCapturer),
            imageSize: imageSize
        )
    }
    
    func startVideoRecording() async throws {
        try await container.webRTCManager.startVideoRecording(
            videoCapturer: nil,
            imageSize: CGSize(
                width: 480,
                height: 640
            )
        )
    }
    
    func stopVideoRecording() async {
        await container.webRTCManager.stopVideoRecording()
    }
    
    func isVideoRecording() -> Bool {
        container.webRTCManager.isVideoRecording()
    }
    
    func updateImageSize(_ imageSize: CGSize) async {
        await container.webRTCManager.updateImageSize(imageSize)
    }
    
    func createDataChannel(setup: DataChannelSetup) async throws {
        try await container.webRTCManager.createDataChannel(setup: setup)
    }
    
    func startConfiguration() async throws {
        try await container.webRTCManager.startConfiguration()
    }
    
    func commitConfiguration() async throws {
        try await container.webRTCManager.commitConfiguration()
    }
    
    func sendCallRequest(to peerID: PeerID) async throws -> UUID {
        try await container.callManager.requestStartCall(peerID)
    }
    
    func acceptIncomingCall(_ callUUID: UUID) async throws {
        let callManager = container.callManager
        
        guard let call = callManager.callWithUUID(callUUID) else { return }
        
        try await callManager.requestAcceptIncomingCall(call)
    }
    
    func endCall(_ callUUID: UUID) async throws {
        let callManager = container.callManager
        
        // handle as success if a call with this id was not found
        guard let call = callManager.callWithUUID(callUUID) else { return }
        
        try await callManager.requestEndCall(call)
    }
    
    func disconnect() async throws {
        try await container.callManager.requestEndAllCalls()
        await container.signalingServer.disconnect()
    }
}
