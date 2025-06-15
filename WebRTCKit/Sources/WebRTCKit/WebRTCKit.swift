import WebRTC

public typealias PeerID = String

@WebRTCActor
public struct WebRTCKit {
    
    /// Initialize the WebRTCKit for production.
    /// 
    /// - Parameters:
    ///   - signalingServer: A reference to the signaling server connection to use.
    ///   - config: The configuration settings to apply.
    ///   - enableVerboseLogging: A Boolean value that determines wether verbose logging for WebRTC is enabled.
    ///   - audioDevice: An optional audio device to use.
    ///   - logLevel: The log level for our logger; defaults to only log errors.
    ///   - loggerDelegate: A delegate for the logger that receives all the logs.
    /// - Returns: The controller to interact with the WebRTCKit.
    public static func initialize(
        signalingServer: SignalingServerConnection,
        config: Config,
        audioDevice: RTCAudioDevice? = nil,
        logLevel: LogLevel = .error,
        loggerDelegate: LoggerDelegate? = nil
    ) async -> WebRTCController {
        
        let container = DIContainer.create(
            config: config,
            webRTCManager: DefaultWebRTCManager(
                factory: WRKRTCPeerConnectionFactoryImpl(
                    audioDevice: audioDevice
                )
            ),
            callProvider: DefaultVoIPCallProvider(),
            pushHandler: DefaultVoIPPushHandler(),
            signalingServer: signalingServer,
            callManager: DefaultCallManager(),
            networkMonitor: DefaultNetworkMonitor(),
            logLevel: logLevel,
            loggerDelegate: loggerDelegate
        )
        
        if logLevel == .verbose {
            RTCSetMinDebugLogLevel(.verbose)
        }
        
        await container.setup()
        
        return WebRTCControllerImpl(container: container)
    }
    
    /// Initialize the framework for testing or previews using mock classes.
    public static func initializeForTesting() -> WebRTCController {
        
        let container = DIContainer.create(
            config: .preview,
            webRTCManager: PreviewWebRTCManager(),
            callProvider: PreviewVoIPCallProvider(),
            pushHandler: PreviewVoIPPushHandler(),
            signalingServer: PreviewSignalingServerConnection(),
            callManager: PreviewCallManager(),
            networkMonitor: PreviewNetworkMonitor(),
            logLevel: .debug,
            loggerDelegate: nil
        )
        
        return WebRTCControllerImpl(container: container)
    }
    
    // for unit tests
    static func initialize(
        config: Config,
        webRTCManager: WebRTCManager,
        callProvider: VoIPCallProvider,
        pushHandler: VoIPPushHandler,
        signalingServer: SignalingServerConnection,
        callManager: CallManager,
        networkMonitor: NetworkMonitor
    ) async -> WebRTCController {
        
        let container = DIContainer.create(
            config: config,
            webRTCManager: webRTCManager,
            callProvider: callProvider,
            pushHandler: pushHandler,
            signalingServer: signalingServer,
            callManager: callManager,
            networkMonitor: networkMonitor,
            logLevel: .debug,
            loggerDelegate: nil
        )
        
        await container.setup()
        
        return WebRTCControllerImpl(container: container)
    }
}

/// An object to interact with the WebRTCKit.
@WebRTCActor
public protocol WebRTCController: AnyObject, Sendable {
    
    /// Set the delegate to handle calls and receive audio & video streams.
    ///
    /// - Parameter delegate: The delegate to handle calls and receive audio & video streams.
    func setCallManagerDelegate(_ delegate: CallManagerDelegate)
    
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
    ///   - videoCapturer: An optional capturer to use, or null for default.
    func setInitialVideoEnabled(enabled: Bool, imageSize: CGSize, videoCapturer: RTCVideoCapturer?)
    
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
    
    /// Initialize a call with another peer.
    ///
    /// - Parameter peerID: The ID of the remote peer.
    func sendCallRequest(to peerID: PeerID) async throws
    
    /// Answer the incoming call request.
    ///
    /// - Parameter accept: True if the request should be accepted.
    func answerCallRequest(accept: Bool) async throws
    
    /// End the call.
    func endCall() async throws
    
    /// End the call and disconnect from the signaling server.
    func disconnect() async throws
    
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
}

public extension WebRTCController {
    
    func setInitialVideoEnabled(enabled: Bool, imageSize: CGSize) {
        setInitialVideoEnabled(
            enabled: enabled,
            imageSize: imageSize,
            videoCapturer: nil
        )
    }
}

final class WebRTCControllerImpl: WebRTCController {
    
    private let container: DIContainer
    
    init(container: DIContainer) {
        self.container = container
    }
    
    func setCallManagerDelegate(_ delegate: CallManagerDelegate) {
        container.callManager.setDelegate(delegate)
    }
    
    func setInitialDataChannels(_ dataChannels: [DataChannelSetup]) {
        container.webRTCManager.setInitialDataChannels(dataChannels)
    }
    
    func setInitialVideoEnabled(enabled: Bool, imageSize: CGSize, videoCapturer: RTCVideoCapturer?) {
        container.webRTCManager.setInitialVideoEnabled(
            enabled: enabled,
            imageSize: imageSize,
            videoCapturer: {
                if let videoCapturer {
                    return VideoCapturer(videoCapturer)
                }
                return nil
            }()
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
                width: 640,
                height: 480
            )
        )
    }
    
    func stopVideoRecording() async {
        await container.webRTCManager.stopVideoRecording()
    }
    
    func isVideoRecording() -> Bool {
        container.webRTCManager.isVideoRecording()
    }
    
    func sendCallRequest(to peerID: PeerID) async throws {
        try await container.callManager.sendCallRequest(to: peerID)
    }
    
    func endCall() async throws {
        try await container.callManager.endCall()
    }
    
    func answerCallRequest(accept: Bool) async throws {
        try await container.callManager.answerCallRequest(accept: accept)
    }
    
    func disconnect() async throws {
        try await container.callManager.disconnect()
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
}
