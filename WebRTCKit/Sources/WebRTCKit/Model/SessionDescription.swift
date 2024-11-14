import WebRTC

struct SessionDescription: Codable {
    let type: Int
    let sdp: String
    
    init(from rtcSdp: RTCSessionDescription) {
        self.type = rtcSdp.type.rawValue
        self.sdp = rtcSdp.sdp
    }
    
    func toRTCSessionDescription() -> RTCSessionDescription {
        RTCSessionDescription(
            type: RTCSdpType(rawValue: type)!,
            sdp: sdp
        )
    }
}
