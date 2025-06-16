import WebRTC

public struct DataChannelSetup: Sendable {
    let label: String
    let configuration: DataChannelConfiguration
    
    var rtcConfig: RTCDataChannelConfiguration {
        configuration.toRTCConfiguration()
    }
    
    public init(
        label: String,
        configuration: DataChannelConfiguration = DataChannelConfiguration()
    ) {
        self.label = label
        self.configuration = configuration
    }
}

public struct DataChannelConfiguration: Sendable {
    
    /// Set to true if ordered delivery is required.
    let isOrdered: Bool

    /**
     Max period in milliseconds in which retransmissions will be sent.
     After this time, no more retransmissions will be sent. -1 if unset.
     */
    let maxPacketLifeTime: Int32

    /// The max number of retransmissions. -1 if unset.
    let maxRetransmits: Int32

    /**
     Set to true if the channel has been externally negotiated and we do not send
     an in-band signalling in the form of an "open" message.
     */
    let isNegotiated: Bool

    /// The id of the data channel.
    let channelId: Int32

    /// Set by the application and opaque to the WebRTC implementation.
    let `protocol`: String
    
    public init(
        isOrdered: Bool = true,
        maxPacketLifeTime: Int32 = -1,
        maxRetransmits: Int32 = -1,
        isNegotiated: Bool = false,
        channelId: Int32 = -1,
        `protocol`: String = ""
    ) {
        self.isOrdered = isOrdered
        self.maxPacketLifeTime = maxPacketLifeTime
        self.maxRetransmits = maxRetransmits
        self.isNegotiated = isNegotiated
        self.channelId = channelId
        self.protocol = `protocol`
    }
    
    public init(rtcConfig: RTCDataChannelConfiguration) {
        self.isOrdered = rtcConfig.isOrdered
        self.maxPacketLifeTime = rtcConfig.maxPacketLifeTime
        self.maxRetransmits = rtcConfig.maxRetransmits
        self.isNegotiated = rtcConfig.isNegotiated
        self.channelId = rtcConfig.channelId
        self.protocol = rtcConfig.protocol
    }
    
    func toRTCConfiguration() -> RTCDataChannelConfiguration {
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
