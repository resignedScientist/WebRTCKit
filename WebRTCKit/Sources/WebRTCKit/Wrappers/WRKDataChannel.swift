import WebRTC

public protocol WRKDataChannel: AnyObject, Sendable {
    
    nonisolated var label: String { get }
    
    var readyState: RTCDataChannelState { get }
    
    func setDelegate(_ delegate: RTCDataChannelDelegate?)
    
    @discardableResult
    func sendData(_ data: RTCDataBuffer) -> Bool
}

final class WRKDataChannelImpl: WRKDataChannel, @unchecked Sendable {
    
    let dataChannel: RTCDataChannel
    let queue = DispatchQueue(label: "com.webrtckit.WRKDataChannel")
    
    nonisolated let label: String
    
    var readyState: RTCDataChannelState {
        queue.sync {
            dataChannel.readyState
        }
    }
    
    init(_ dataChannel: RTCDataChannel) {
        self.dataChannel = dataChannel
        self.label = dataChannel.label
    }
    
    func setDelegate(_ delegate: RTCDataChannelDelegate?) {
        queue.sync {
            dataChannel.delegate = delegate
        }
    }
    
    func sendData(_ data: RTCDataBuffer) -> Bool {
        queue.sync {
            dataChannel.sendData(data)
        }
    }
}
