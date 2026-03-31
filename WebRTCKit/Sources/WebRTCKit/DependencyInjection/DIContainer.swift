import WebRTC

struct DIContainer: Sendable {
    private(set) static var shared: DIContainer?
    
    let config: WebRTCKitConfig
    let webRTCManager: WebRTCManager
    let pushHandler: VoIPPushHandler
    let pushCredentialProvider: PushCredentialProviding
    let signalingServer: SignalingServerConnection
    let networkMonitor: NetworkMonitor
    let logLevel: LogLevel
    let loggerDelegate: LoggerDelegate?
    let callManager: CallManager
    let providerDelegate: ProviderDelegate
    
    private init(
        config: WebRTCKitConfig,
        webRTCManager: WebRTCManager,
        pushHandler: VoIPPushHandler,
        pushCredentialProvider: PushCredentialProviding,
        signalingServer: SignalingServerConnection,
        networkMonitor: NetworkMonitor,
        logLevel: LogLevel,
        loggerDelegate: LoggerDelegate?,
        callManager: CallManager,
        providerDelegate: ProviderDelegate
    ) {
        self.config = config
        self.webRTCManager = webRTCManager
        self.pushHandler = pushHandler
        self.pushCredentialProvider = pushCredentialProvider
        self.signalingServer = signalingServer
        self.networkMonitor = networkMonitor
        self.logLevel = logLevel
        self.loggerDelegate = loggerDelegate
        self.callManager = callManager
        self.providerDelegate = providerDelegate
    }
    
    static func create(
        config: WebRTCKitConfig,
        webRTCManager: WebRTCManager,
        pushHandler: VoIPPushHandler,
        pushCredentialProvider: PushCredentialProviding,
        signalingServer: SignalingServerConnection,
        networkMonitor: NetworkMonitor,
        logLevel: LogLevel,
        loggerDelegate: LoggerDelegate?,
        callManager: CallManager,
        providerDelegate: ProviderDelegate
    ) -> DIContainer {
        
        let container = DIContainer(
            config: config,
            webRTCManager: webRTCManager,
            pushHandler: pushHandler,
            pushCredentialProvider: pushCredentialProvider,
            signalingServer: signalingServer,
            networkMonitor: networkMonitor,
            logLevel: logLevel,
            loggerDelegate: loggerDelegate,
            callManager: callManager,
            providerDelegate: providerDelegate
        )
        DIContainer.shared = container
        return container
    }
    
    func setup() async {
        // TODO: still needed?
//        await callManager.setup()
    }
}
