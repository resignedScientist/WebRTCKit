import Network

final class DefaultNetworkMonitor: NetworkMonitor {
    
    @Inject(\.signalingServer) private var signalingServer
    
    private let monitor: WRKNetworkPathMonitor
    private let log = Logger(caller: "NetworkMonitor")
    
    private var currentStatus: NWPath.Status = .satisfied
    
    init(monitor: WRKNetworkPathMonitor = WRKNetworkPathMonitorImpl(NWPathMonitor())) {
        self.monitor = monitor
    }
    
    func startMonitoring() {
        monitor.setPathUpdateHandler { [weak self] path in
            Task { [weak self] in
                await self?.pathDidUpdate(path)
            }
        }
        monitor.start(queue: .main)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
}

// MARK: - Private functions

private extension DefaultNetworkMonitor {
    
    func pathDidUpdate(_ path: WRKNetworkPath) {
        switch path.status {
        case .satisfied:
            if currentStatus != .satisfied {
                log.info("Connection is satisfied.")
                signalingServer.onConnectionSatisfied()
            }
        case .unsatisfied:
            if currentStatus != .unsatisfied {
                log.info("Connection is unsatisfied")
                signalingServer.onConnectionUnsatisfied()
            }
        case .requiresConnection:
            if currentStatus != .requiresConnection {
                log.info("Connection is requiresConnection")
            }
        @unknown default:
            break
        }
        
        self.currentStatus = path.status
    }
}
