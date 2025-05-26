import WebRTC

@WebRTCActor
protocol WRKRTCAudioSessionDelegate: AnyObject, Sendable {
    
    func audioSessionDidStartPlayOrRecord(_ session: WRKRTCAudioSession)
    
    func audioSessionDidSetActive(_ session: WRKRTCAudioSession, active: Bool)
}
