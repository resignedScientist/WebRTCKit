import WebRTC

extension RTCPeerConnectionState: @retroactive CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .new:
            return "new"
        case .connecting:
            return "connecting"
        case .connected:
            return "connected"
        case .disconnected:
            return "disconnected"
        case .failed:
            return "failed"
        case .closed:
            return "closed"
        @unknown default:
            return "unknown"
        }
    }
}
