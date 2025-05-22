import WebRTC

@WebRTCActor
protocol WRKRTCAudioSessionDelegate: AnyObject, Sendable {
    
    func audioSessionDidStartPlayOrRecord(_ session: WRKRTCAudioSession)
}
