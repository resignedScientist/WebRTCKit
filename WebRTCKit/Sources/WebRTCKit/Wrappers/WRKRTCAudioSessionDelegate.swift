import WebRTC

@WebRTCActor
protocol WRKRTCAudioSessionDelegate: AnyObject, Sendable {
    
    func audioSessionDidStartPlayOrRecord(_ session: WRKRTCAudioSession)
    
    func audioSessionWillSetActive(_ session: WRKRTCAudioSession, active: Bool)
    
    func audioSessionDidSetActive(_ session: WRKRTCAudioSession, active: Bool)
}
