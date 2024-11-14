import Network

protocol WRKNetworkPathMonitor: Actor, Sendable {
    
    func setPathUpdateHandler(_ updateHandler: @Sendable @escaping (_ newPath: WRKNetworkPath) -> Void)
    
    func start(queue: DispatchQueue)
    
    func cancel()
}

actor WRKNetworkPathMonitorImpl: WRKNetworkPathMonitor {
    
    let pathMonitor: NWPathMonitor
    
    private var pathUpdateHandler: (@Sendable (WRKNetworkPath) -> Void)?
    
    init(_ pathMonitor: NWPathMonitor) {
        self.pathMonitor = pathMonitor
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { [weak self] in
                await self?.handlePathUpdate(path)
            }
        }
    }
    
    func setPathUpdateHandler(_ updateHandler: @Sendable @escaping (WRKNetworkPath) -> Void) {
        self.pathUpdateHandler = updateHandler
    }
    
    func start(queue: DispatchQueue) {
        pathMonitor.start(queue: queue)
    }
    
    func cancel() {
        pathMonitor.cancel()
    }
    
    private func handlePathUpdate(_ path: NWPath) {
        pathUpdateHandler?(
            WRKNetworkPathImpl(path)
        )
    }
}
