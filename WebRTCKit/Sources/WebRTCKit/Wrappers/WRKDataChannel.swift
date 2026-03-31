import WebRTC

public protocol WRKDataChannel: AnyObject, Sendable {
    
    var label: String { get }
    
    var readyState: RTCDataChannelState { get }
    
    var channelId: Int32 { get }
    
    func setDelegate(_ delegate: RTCDataChannelDelegate?)
    
    @discardableResult
    func sendData(_ data: Data) async -> Bool
    
    func close()
}

final class WRKDataChannelImpl: WRKDataChannel {
    
    let dataChannel: RTCDataChannel
    
    let label: String
    
    var readyState: RTCDataChannelState {
        dataChannel.readyState
    }
    
    var channelId: Int32 {
        dataChannel.channelId
    }
    
    init(_ dataChannel: RTCDataChannel) {
        self.dataChannel = dataChannel
        self.label = dataChannel.label
    }
    
    func setDelegate(_ delegate: RTCDataChannelDelegate?) {
        dataChannel.delegate = delegate
    }
    
    func sendData(_ data: Data) async -> Bool {
        let buffer = RTCDataBuffer(data: data, isBinary: true)
        let success = self.dataChannel.sendData(buffer)
        return success
    }
    
    func close() {
        dataChannel.close()
    }
}
