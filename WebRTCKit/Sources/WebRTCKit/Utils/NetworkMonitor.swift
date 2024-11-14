@WebRTCActor
protocol NetworkMonitor {
    
    func startMonitoring() async
    
    func stopMonitoring() async
}
