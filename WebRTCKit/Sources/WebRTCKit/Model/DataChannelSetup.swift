import WebRTC

public struct DataChannelSetup {
    let label: String
    let configuration: RTCDataChannelConfiguration
    
    public init(
        label: String,
        configuration: RTCDataChannelConfiguration = RTCDataChannelConfiguration()
    ) {
        self.label = label
        self.configuration = configuration
    }
}
