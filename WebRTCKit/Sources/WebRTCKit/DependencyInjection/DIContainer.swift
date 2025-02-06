import WebRTC

@WebRTCActor
struct DIContainer: Sendable {
    
    let config: WebRTCKitConfig
    let webRTCManager: WebRTCManager
    let callProvider: VoIPCallProvider
    let pushHandler: VoIPPushHandler
    let signalingServer: SignalingServerConnection
    let callManager: CallManager
    let networkMonitor: NetworkMonitor
    let logLevel: LogLevel
    
    init(
        config: WebRTCKitConfig,
        webRTCManager: WebRTCManager,
        callProvider: VoIPCallProvider,
        pushHandler: VoIPPushHandler,
        signalingServer: SignalingServerConnection,
        callManager: CallManager,
        networkMonitor: NetworkMonitor,
        logLevel: LogLevel
    ) {
        self.config = config
        self.webRTCManager = webRTCManager
        self.callProvider = callProvider
        self.pushHandler = pushHandler
        self.signalingServer = signalingServer
        self.callManager = callManager
        self.networkMonitor = networkMonitor
        self.logLevel = logLevel
    }
    
    func setup() async {
        await callManager.setup()
    }
}

// MARK: - Instance actor

extension DIContainer {
    
    actor Instance {
        static var shared: DIContainer?
    }
}
