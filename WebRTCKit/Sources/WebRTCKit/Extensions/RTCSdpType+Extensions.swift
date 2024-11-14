import WebRTC

extension RTCSdpType: @retroactive CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .offer:
            return "offer"
        case .prAnswer:
            return "prAnswer"
        case .answer:
            return "answer"
        case .rollback:
            return "rollback"
        @unknown default:
            return "unknown"
        }
    }
}
