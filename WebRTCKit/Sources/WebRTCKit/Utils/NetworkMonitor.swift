@WebRTCActor
protocol NetworkMonitor {
    
    /// Starts monitoring network path updates asynchronously.
    /// This method sets up a handler to receive updates about the network path status.
    func startMonitoring() async
    
    /// Stops monitoring network path updates asynchronously.
    /// This method cancels the ongoing monitoring process.
    func stopMonitoring() async
}
