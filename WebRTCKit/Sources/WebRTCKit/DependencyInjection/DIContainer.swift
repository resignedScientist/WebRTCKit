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
        for mode: InitializingMode,
        signalingServer: SignalingServerConnection,
        config: Config,
        audioDevice: RTCAudioDevice?
    ) {
        self.config = config
        
        // This one we need to get from outside
        // as every app needs to use their own implementation of it.
        self.signalingServer = signalingServer
        
        switch mode {
        case .previews:
            self.webRTCManager = PreviewWebRTCManager()
            self.callProvider = PreviewVoIPCallProvider()
            self.pushHandler = PreviewVoIPPushHandler()
            self.callManager = PreviewCallManager()
            self.networkMonitor = PreviewNetworkMonitor()
        case .production:
            self.webRTCManager = DefaultWebRTCManager(
                factory: WRKRTCPeerConnectionFactoryImpl(
                    audioDevice: audioDevice
                )
            )
            self.callProvider = DefaultVoIPCallProvider()
            self.pushHandler = DefaultVoIPPushHandler()
            self.callManager = DefaultCallManager()
            self.networkMonitor = DefaultNetworkMonitor()
        }
    }
    
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
