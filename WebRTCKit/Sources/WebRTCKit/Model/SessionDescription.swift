import WebRTC

struct SessionDescription: Codable, Sendable {
    let type: Int
    let sdp: String
    
    func toRTCSessionDescription() -> RTCSessionDescription {
        RTCSessionDescription(
            type: RTCSdpType(rawValue: type)!,
            sdp: sdp
        )
    }
}

extension SessionDescription {
    
    nonisolated init(from rtcSdp: RTCSessionDescription) {
        self.type = rtcSdp.type.rawValue
        self.sdp = rtcSdp.sdp
    }
    
    static let rollback = SessionDescription(
        type: RTCSdpType.rollback.rawValue,
        sdp: ""
    )
}
