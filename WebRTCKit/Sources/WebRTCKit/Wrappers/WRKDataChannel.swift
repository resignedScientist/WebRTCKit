import WebRTC

public protocol WRKDataChannel: AnyObject, Sendable {
    
    nonisolated var label: String { get }
    
    var readyState: RTCDataChannelState { get }
    
    func setDelegate(_ delegate: RTCDataChannelDelegate?)
    
    @discardableResult
    func sendData(_ data: Data) async -> Bool
    
    func close()
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
    
    func sendData(_ data: Data) async -> Bool {
        return await withCheckedContinuation { continuation in
            queue.async {
                let buffer = RTCDataBuffer(data: data, isBinary: true)
                let success = self.dataChannel.sendData(buffer)
                continuation.resume(returning: success)
            }
        }
    }
    
    func close() {
        queue.async {
            self.dataChannel.close()
        }
    }
}
