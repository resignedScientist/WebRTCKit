import WebRTC

extension RTCIceGatheringState: @retroactive CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .new:
            return "new"
        case .gathering:
            return "gathering"
        case .complete:
            return "complete"
        @unknown default:
            return "unknown"
        }
    }
}
