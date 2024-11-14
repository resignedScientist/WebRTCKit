import WebRTC

public protocol WRKDataChannel: Actor {
    
    var label: String { get }
    
    var readyState: RTCDataChannelState { get }
    
    func setDelegate(_ delegate: RTCDataChannelDelegate?)
    
    @discardableResult
    func sendData(_ data: RTCDataBuffer) -> Bool
}

actor WRKDataChannelImpl: WRKDataChannel {
    
    let dataChannel: RTCDataChannel
    
    var label: String { dataChannel.label }
    
    var readyState: RTCDataChannelState {
        dataChannel.readyState
    }
    
    init(_ dataChannel: RTCDataChannel) {
        self.dataChannel = dataChannel
    }
    
    func setDelegate(_ delegate: RTCDataChannelDelegate?) {
        dataChannel.delegate = delegate
    }
    
    func sendData(_ data: RTCDataBuffer) -> Bool {
        dataChannel.sendData(data)
    }
}
