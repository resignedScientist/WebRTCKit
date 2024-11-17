import WebRTC

struct AudioSessionConfiguration: Sendable {
    
    let description: String
    let category: String
    let categoryOptions: AVAudioSession.CategoryOptions
    let inputNumberOfChannels: Int
    let outputNumberOfChannels: Int
    let ioBufferDuration: TimeInterval
    let mode: String
    let sampleRate: Double
    
    init(from config: RTCAudioSessionConfiguration) {
        self.description = config.description
        self.category = config.category
        self.categoryOptions = config.categoryOptions
        self.inputNumberOfChannels = config.inputNumberOfChannels
        self.outputNumberOfChannels = config.outputNumberOfChannels
        self.ioBufferDuration = config.ioBufferDuration
        self.mode = config.mode
        self.sampleRate = config.sampleRate
    }
    
    func toRTCAudioSessionConfiguration() -> RTCAudioSessionConfiguration {
        let config = RTCAudioSessionConfiguration()
        config.category = category
        config.categoryOptions = categoryOptions
        config.inputNumberOfChannels = inputNumberOfChannels
        config.outputNumberOfChannels = outputNumberOfChannels
        config.ioBufferDuration = ioBufferDuration
        config.mode = mode
        config.sampleRate = sampleRate
        
        return config
    }
}
