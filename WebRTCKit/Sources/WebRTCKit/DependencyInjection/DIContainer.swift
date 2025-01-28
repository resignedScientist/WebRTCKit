import WebRTC

@WebRTCActor
struct DIContainer: Sendable {
    
    let config: Config
    let webRTCManager: WebRTCManager
    let callProvider: VoIPCallProvider
    let pushHandler: VoIPPushHandler
    let signalingServer: SignalingServerConnection
    let callManager: CallManager
    let networkMonitor: NetworkMonitor
    
    init(
        config: Config,
        webRTCManager: WebRTCManager,
        callProvider: VoIPCallProvider,
        pushHandler: VoIPPushHandler,
        signalingServer: SignalingServerConnection,
        callManager: CallManager,
        networkMonitor: NetworkMonitor
    ) {
        self.config = config
        self.webRTCManager = webRTCManager
        self.callProvider = callProvider
        self.pushHandler = pushHandler
        self.signalingServer = signalingServer
        self.callManager = callManager
        self.networkMonitor = networkMonitor
    }
    
    func setup() async {
        await callManager.setup()
    }
}
