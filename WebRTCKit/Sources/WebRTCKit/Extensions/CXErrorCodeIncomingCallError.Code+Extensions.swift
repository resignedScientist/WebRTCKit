import CallKit

extension CXErrorCodeIncomingCallError.Code: @retroactive CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .unknown:
            return "unknown"
        case .unentitled:
            return "unentitled"
        case .callUUIDAlreadyExists:
            return "callUUIDAlreadyExists"
        case .filteredByDoNotDisturb:
            return "filteredByDoNotDisturb"
        case .filteredByBlockList:
            return "filteredByBlockList"
        case .filteredDuringRestrictedSharingMode:
            return "filteredDuringRestrictedSharingMode"
        case .callIsProtected:
            return "callIsProtected"
        case .filteredBySensitiveParticipants:
            return "filteredBySensitiveParticipants"
        @unknown default:
            return "unknown"
        }
    }
}
