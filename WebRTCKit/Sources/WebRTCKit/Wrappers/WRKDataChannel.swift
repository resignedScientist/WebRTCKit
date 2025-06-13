import WebRTC

public protocol WRKDataChannel: AnyObject, Sendable {
    
    nonisolated var label: String { get }
    
    var readyState: RTCDataChannelState { get }
    
    var channelId: Int32 { get }
    
    func setDelegate(_ delegate: RTCDataChannelDelegate?)
    
    @discardableResult
    func sendData(_ data: Data) async -> Bool
    
    func close()
}

final class WRKDataChannelImpl: WRKDataChannel, @unchecked Sendable {
    
    let dataChannel: RTCDataChannel
    let queue = WebRTCActor.queue
    
    nonisolated let label: String
    
    var readyState: RTCDataChannelState {
        WebRTCActor.checkSync {
            dataChannel.readyState
        }
    }
    
    var channelId: Int32 {
        WebRTCActor.checkSync {
            dataChannel.channelId
        }
    }
    
    init(_ dataChannel: RTCDataChannel) {
        self.dataChannel = dataChannel
        self.label = dataChannel.label
    }
    
    func setDelegate(_ delegate: RTCDataChannelDelegate?) {
        WebRTCActor.checkSync {
            dataChannel.delegate = delegate
        }
    }
    
    func sendData(_ data: Data) async -> Bool {
        return await withCheckedContinuation { continuation in
            WebRTCActor.checkAsync {
                let buffer = RTCDataBuffer(data: data, isBinary: true)
                let success = self.dataChannel.sendData(buffer)
                continuation.resume(returning: success)
            }
        }
    }
    
    func close() {
        WebRTCActor.checkAsync {
            self.dataChannel.close()
        }
    }
}
