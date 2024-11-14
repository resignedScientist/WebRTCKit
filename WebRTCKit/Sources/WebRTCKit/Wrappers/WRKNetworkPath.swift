import Network

protocol WRKNetworkPath: AnyObject, Sendable {
    
    var status: NWPath.Status { get }
}

final class WRKNetworkPathImpl: WRKNetworkPath {
    
    let path: NWPath
    
    var status: NWPath.Status {
        path.status
    }
    
    init(_ path: NWPath) {
        self.path = path
    }
}
