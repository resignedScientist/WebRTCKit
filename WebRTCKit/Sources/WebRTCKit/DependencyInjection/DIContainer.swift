import WebRTC

@WebRTCActor
struct DIContainer: Sendable {
    private(set) static var shared: DIContainer?
    
    let config: WebRTCKitConfig
    let webRTCManager: WebRTCManager
    let callProvider: VoIPCallProvider
    let pushHandler: VoIPPushHandler
    let signalingServer: SignalingServerConnection
    let callManager: CallManager
    let networkMonitor: NetworkMonitor
    let logLevel: LogLevel
    let loggerDelegate: LoggerDelegate?
    
    private init(
        config: WebRTCKitConfig,
        webRTCManager: WebRTCManager,
        callProvider: VoIPCallProvider,
        pushHandler: VoIPPushHandler,
        signalingServer: SignalingServerConnection,
        callManager: CallManager,
        networkMonitor: NetworkMonitor,
        logLevel: LogLevel,
        loggerDelegate: LoggerDelegate?
    ) {
        self.config = config
        self.webRTCManager = webRTCManager
        self.callProvider = callProvider
        self.pushHandler = pushHandler
        self.signalingServer = signalingServer
        self.callManager = callManager
        self.networkMonitor = networkMonitor
        self.logLevel = logLevel
        self.loggerDelegate = loggerDelegate
    }
    
    static func create(
        config: WebRTCKitConfig,
        webRTCManager: WebRTCManager,
        callProvider: VoIPCallProvider,
        pushHandler: VoIPPushHandler,
        signalingServer: SignalingServerConnection,
        callManager: CallManager,
        networkMonitor: NetworkMonitor,
        logLevel: LogLevel,
        loggerDelegate: LoggerDelegate?
    ) -> DIContainer {
        let container = DIContainer(
            config: config,
            webRTCManager: webRTCManager,
            callProvider: callProvider,
            pushHandler: pushHandler,
            signalingServer: signalingServer,
            callManager: callManager,
            networkMonitor: networkMonitor,
            logLevel: logLevel,
            loggerDelegate: loggerDelegate
        )
        DIContainer.shared = container
        return container
    }
    
    func setup() async {
        await callManager.setup()
    }
}
