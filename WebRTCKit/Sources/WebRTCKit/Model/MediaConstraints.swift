import WebRTC

struct MediaConstraints {
    let mandatoryConstraints: [String: String]?
    let optionalConstraints: [String: String]?
    
    func toRtcMediaConstraints() -> RTCMediaConstraints {
        RTCMediaConstraints(
            mandatoryConstraints: mandatoryConstraints,
            optionalConstraints: optionalConstraints
        )
    }
}
