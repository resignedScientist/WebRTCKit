import WebRTC

struct ICECandidate: Codable, Equatable {
    let candidate: String
    let sdpMLineIndex: Int32
    let sdpMid: String?
    
    init(from rtcCandidate: RTCIceCandidate) {
        self.candidate = rtcCandidate.sdp
            // decrease the network cost of relays
            .replacingOccurrences(of: "network-cost 900", with: "network-cost 10")
        self.sdpMLineIndex = rtcCandidate.sdpMLineIndex
        self.sdpMid = rtcCandidate.sdpMid
    }
    
    func toRTCIceCandidate() -> RTCIceCandidate {
        RTCIceCandidate(
            sdp: candidate,
            sdpMLineIndex: sdpMLineIndex,
            sdpMid: sdpMid
        )
    }
}
