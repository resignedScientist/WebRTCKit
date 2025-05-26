import WebRTC

@WebRTCActor
protocol WRKRTCAudioSessionDelegate: AnyObject, Sendable {
    
    func audioSessionDidSetActive(_ session: WRKRTCAudioSession, active: Bool)
}
