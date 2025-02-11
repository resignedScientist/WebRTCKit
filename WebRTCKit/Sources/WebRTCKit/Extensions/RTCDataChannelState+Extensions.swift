import WebRTC

extension RTCDataChannelState: @retroactive CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .connecting:
            return "connecting"
        case .open:
            return "open"
        case .closing:
            return "closing"
        case .closed:
            return "closed"
        @unknown default:
            return "unknown"
        }
    }
}
