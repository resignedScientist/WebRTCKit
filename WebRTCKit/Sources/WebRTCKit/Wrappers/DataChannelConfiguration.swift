import WebRTC

struct DataChannelConfiguration: Sendable {
    
    let isOrdered: Bool
    let maxPacketLifeTime: Int32
    let maxRetransmits: Int32
    let isNegotiated: Bool
    let channelId: Int32
    let `protocol`: String
    
    init(rtcConfig: RTCDataChannelConfiguration) {
        isOrdered = rtcConfig.isOrdered
        maxPacketLifeTime = rtcConfig.maxPacketLifeTime
        maxRetransmits = rtcConfig.maxRetransmits
        isNegotiated = rtcConfig.isNegotiated
        channelId = rtcConfig.channelId
        `protocol` = rtcConfig.protocol
    }
    
    func toRTCConfig() -> RTCDataChannelConfiguration {
        let rtcConfig = RTCDataChannelConfiguration()
        rtcConfig.isOrdered = isOrdered
        rtcConfig.maxPacketLifeTime = maxPacketLifeTime
        rtcConfig.maxRetransmits = maxRetransmits
        rtcConfig.isNegotiated = isNegotiated
        rtcConfig.channelId = channelId
        rtcConfig.protocol = `protocol`
        
        return rtcConfig
    }
}
