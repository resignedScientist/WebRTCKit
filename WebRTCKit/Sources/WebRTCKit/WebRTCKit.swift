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
        
        DIContainer.Instance.logLevel = logLevel
        DIContainer.Instance.loggerDelegate = loggerDelegate
        
        let container = DIContainer(
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
            networkMonitor: DefaultNetworkMonitor()
        )
        
        DIContainer.Instance.shared = container
        
        if logLevel == .verbose {
            RTCSetMinDebugLogLevel(.verbose)
        }
        
        await container.setup()
        
        return WebRTCControllerImpl(container: container)
    }
    
    /// Initialize the framework for testing or previews using mock classes.
    public static func initializeForTesting() -> WebRTCController {
        
        DIContainer.Instance.logLevel = .debug
        
        let container = DIContainer(
            config: .preview,
            webRTCManager: PreviewWebRTCManager(),
            callProvider: PreviewVoIPCallProvider(),
            pushHandler: PreviewVoIPPushHandler(),
            signalingServer: PreviewSignalingServerConnection(),
            callManager: PreviewCallManager(),
            networkMonitor: PreviewNetworkMonitor()
        )
        
        DIContainer.Instance.shared = container
        
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
        
        DIContainer.Instance.logLevel = .debug
        
        let container = DIContainer(
            config: config,
            webRTCManager: webRTCManager,
            callProvider: callProvider,
            pushHandler: pushHandler,
            signalingServer: signalingServer,
            callManager: callManager,
            networkMonitor: networkMonitor
        )
        
        DIContainer.Instance.shared = container
        
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
    
    /// Connect to the signaling server and prepares the peer connection.
    ///
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
    
    /// Create a peer-to-peer data channel to the other peer.
    /// To receive data, just set the channels delegate.
    /// 
    /// - Parameters:
    ///   - label: The identifier of the channel.
    ///   - config: The configuration of the channel or nil to use the default one.
    ///
    /// - Returns: The created data channel.
    func createDataChannel(label: String, config: RTCDataChannelConfiguration) async throws -> WRKDataChannel?
    
    /// Create a peer-to-peer data channel to the other peer.
    /// To receive data, just set the channels delegate.
    ///
    /// - Parameters:
    ///   - label: The identifier of the channel.
    ///
    /// - Returns: The created data channel using the default configuration.
    func createDataChannel(label: String) async throws -> WRKDataChannel?
    
    /// Start the configuration of things like data channels and other parameters.
    /// While doing the configuration, there is no re-negotiation happening.
    func startConfiguration() async throws
    
    /// Finish the configuration. After calling it, the re-negotiation is happening.
    func commitConfiguration() async throws
}

final class WebRTCControllerImpl: WebRTCController {
    
    private let container: DIContainer
    
    init(container: DIContainer) {
        self.container = container
    }
    
    func setCallManagerDelegate(_ delegate: CallManagerDelegate) {
        container.callManager.setDelegate(delegate)
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
    
    func createDataChannel(label: String, config: RTCDataChannelConfiguration) async throws -> WRKDataChannel? {
        try await container.webRTCManager.createDataChannel(
            label: label,
            config: config
        )
    }
    
    func createDataChannel(label: String) async throws -> (any WRKDataChannel)? {
        try await container.webRTCManager.createDataChannel(label: label, config: nil)
    }
    
    func startConfiguration() async throws {
        try await container.webRTCManager.startConfiguration()
    }
    
    func commitConfiguration() async throws {
        try await container.webRTCManager.commitConfiguration()
    }
}
