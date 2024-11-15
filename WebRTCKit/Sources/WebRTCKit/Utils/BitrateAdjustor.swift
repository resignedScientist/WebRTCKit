import Foundation

private enum BitrateType: String {
    case audio
    case video
}

@WebRTCActor
protocol BitrateAdjustor {
    
    func start(peerConnection: WRKRTCPeerConnection)
    
    func stop()
    
    func setStartEncodingParameters(peerConnection: WRKRTCPeerConnection)
}

final class BitrateAdjustorImpl: BitrateAdjustor {
    
    @Inject(\.config) private var config
    
    private let audioAdjustmentTracker: AdjustmentTracker = AdjustmentTrackerImpl(cooldownDuration: 3)
    private let videoAdjustmentTracker: AdjustmentTracker = AdjustmentTrackerImpl(cooldownDuration: 3)
    private let audioNetworkDataCache: NetworkDataCache = NetworkDataCacheImpl()
    private let videoNetworkDataCache: NetworkDataCache = NetworkDataCacheImpl()
    private var tasks: [Task<Void, Never>] = []
    
    func start(peerConnection: WRKRTCPeerConnection) {
        registerStatisticObservers(peerConnection: peerConnection)
    }
    
    func stop() {
        tasks.cancelAll()
    }
    
    func setStartEncodingParameters(peerConnection: any WRKRTCPeerConnection) {
        
        // set video parameters
        if
            let videoSender = peerConnection.senders.first(where: { $0.track?.kind == BitrateType.video.rawValue }),
            let encoding = videoSender.parameters.encodings.first
        {
            let parameters = videoSender.parameters
            encoding.minBitrateBps = NSNumber(value: config.video.minBitrate)
            encoding.maxBitrateBps = NSNumber(value: config.video.startBitrate)
            encoding.maxFramerate = 30
            encoding.scaleResolutionDownBy = calculateVideoScaling(for: config.video.startBitrate)
            parameters.encodings = [encoding]
            videoSender.parameters = parameters
        }
        
        // set audio parameters
        if
            let audioSender = peerConnection.senders.first(where: { $0.track?.kind == BitrateType.audio.rawValue }),
            let encoding = audioSender.parameters.encodings.first
        {
            let parameters = audioSender.parameters
            encoding.minBitrateBps = NSNumber(value: config.audio.minBitrate)
            encoding.maxBitrateBps = NSNumber(value: config.audio.startBitrate)
            parameters.encodings = [encoding]
            audioSender.parameters = parameters
        }
    }
}

// MARK: - Private functions

private extension BitrateAdjustorImpl {
    
    func registerStatisticObservers(peerConnection: WRKRTCPeerConnection) {
        
        // fast task (every second)
        Task {
            while !Task.isCancelled {
                
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
                guard !Task.isCancelled else { return }
                
                async let videoTask: Void = runFastTask(for: .video, peerConnection: peerConnection)
                async let audioTask: Void = runFastTask(for: .audio, peerConnection: peerConnection)
                
                _ = await (videoTask, audioTask)
            }
        }.store(in: &tasks)
        
        // slow task (every 5 seconds)
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                
                guard !Task.isCancelled else { return }
                
                async let videoTask: Void = runSlowTask(for: .video, peerConnection: peerConnection)
                async let audioTask: Void = runSlowTask(for: .audio, peerConnection: peerConnection)
                
                _ = await (videoTask, audioTask)
            }
        }.store(in: &tasks)
    }
    
    func fetchStats(peerConnection: WRKRTCPeerConnection, for type: BitrateType) async -> NetworkDataPoint? {
        let report = await peerConnection.statistics()
        var packetsLost: Int?
        var packetsSent: Int?
        
        for stats in report.statistics.values {
            guard stats.values["kind"] as? NSString == type.rawValue as NSString else { continue }
            
            if stats.type == "remote-inbound-rtp" {
                guard let lost = stats.values["packetsLost"] as? NSNumber else { continue }
                packetsLost = lost.intValue
            } else if stats.type == "outbound-rtp" {
                guard let sent = stats.values["packetsSent"] as? NSNumber else { continue }
                packetsSent = sent.intValue
            }
            
            // break the loop if both values have been found
            if packetsLost != nil && packetsSent != nil {
                break
            }
        }
        
        guard let packetsLost, let packetsSent else { return nil }
        
        return NetworkDataPoint(
            packetsSent: packetsSent,
            packetsLost: packetsLost,
            timestamp: Date()
        )
    }
    
    func shouldChangeBitrate(for type: BitrateType, packetLoss: Double) -> BitrateChange {
        
        let bitrateConfig = getConfig(for: type)
        
        if packetLoss >= bitrateConfig.criticalPacketLossThreshold {
            return .criticalDecrease
        } else if packetLoss >= bitrateConfig.highPacketLossThreshold {
            return .decrease
        } else if packetLoss <= bitrateConfig.lowPacketLossThreshold {
            return .increase
        } else {
            return .maintain
        }
    }
    
    func adjustBitrate(
        for type: BitrateType,
        peerConnection: WRKRTCPeerConnection,
        packetLoss: Double,
        handleCriticalPacketLoss: Bool
    ) async {
        
        guard
            let sender = peerConnection.senders.first(where: { $0.track?.kind == type.rawValue }),
            let encoding = sender.parameters.encodings.first,
            var bitrate = encoding.maxBitrateBps?.intValue
        else { return }
        
        let originalBitrate = bitrate
        let bitrateConfig = getConfig(for: type)
        
        let change = shouldChangeBitrate(for: type, packetLoss: packetLoss)
        switch change {
        case .increase:
            let newBitrate = Int(Double(bitrate) * (1 + bitrateConfig.bitrateStepUp))
            bitrate = min(newBitrate, bitrateConfig.maxBitrate)
        case .decrease:
            let newBitrate = Int(Double(bitrate) * (1 - bitrateConfig.bitrateStepDown))
            bitrate = max(newBitrate, bitrateConfig.minBitrate)
        case .criticalDecrease:
            guard handleCriticalPacketLoss else { return }
            let newBitrate = Int(Double(bitrate) * (1 - bitrateConfig.bitrateStepCriticalDown))
            bitrate = max(newBitrate, bitrateConfig.minBitrate)
        case .maintain:
            return
        }
        
        guard bitrate != originalBitrate else { return }
        
        encoding.maxBitrateBps = NSNumber(value: bitrate)
        
        if type == .video {
            let scalingFactor = calculateVideoScaling(for: bitrate)
            encoding.scaleResolutionDownBy = scalingFactor
            print("ℹ️ Adjusted video bitrate to \(bitrate) with scaling factor \(scalingFactor).")
        } else {
            print("ℹ️ Adjusted audio bitrate to \(bitrate).")
        }
        
        let parameters = sender.parameters
        parameters.encodings = [encoding]
        sender.parameters = parameters
        
        switch type {
        case .audio:
            await audioAdjustmentTracker.trackAdjustment()
        case .video:
            await videoAdjustmentTracker.trackAdjustment()
        }
    }
    
    func calculateVideoScaling(for bitrate: Int) -> NSNumber {
        switch bitrate {
        case let b where b >= 2_500_000:
            return NSNumber(value: 1.0)
        case 1_500_000..<2_500_000:
            return NSNumber(value: 1 + 1/3) // 720p / 1.333 ≈ 540p
        case 1_000_000..<1_500_000:
            return NSNumber(value: 1.5) // 720 / 1.5 = 480p
        case 600_000..<1_000_000:
            return NSNumber(value: 2.0) // 720 / 2 = 360p
        case 350_000..<600_000:
            return NSNumber(value: 3.0) // 720 / 3 = 240p
        default:
            return NSNumber(value: 5.0) // 720 / 5 = 144p
        }
    }
    
    func getConfig(for type: BitrateType) -> Config.BitrateConfig {
        switch type {
        case .audio:
            return config.audio
        case .video:
            return config.video
        }
    }
    
    func getNetworkDataCache(for type: BitrateType) -> NetworkDataCache {
        switch type {
        case .audio:
            return audioNetworkDataCache
        case .video:
            return videoNetworkDataCache
        }
    }
    
    func getAdjustmentTracker(for type: BitrateType) -> AdjustmentTracker {
        switch type {
        case .audio:
            return audioAdjustmentTracker
        case .video:
            return videoAdjustmentTracker
        }
    }
    
    func runFastTask(for type: BitrateType, peerConnection: WRKRTCPeerConnection) async {
        guard let dataPoint = await fetchStats(
            peerConnection: peerConnection,
            for: type
        ) else { return }
        
        let networkDataCache = getNetworkDataCache(for: type)
        let config = getConfig(for: type)
        
        await networkDataCache.addDataPoint(dataPoint)
        
        guard let packetLoss = await networkDataCache.getPacketLossRate(
            overLast: 1
        ) else { return }
        
        if packetLoss >= config.criticalPacketLossThreshold {
            await adjustBitrate(
                for: type,
                peerConnection: peerConnection,
                packetLoss: packetLoss,
                handleCriticalPacketLoss: true
            )
        }
    }
    
    func runSlowTask(for type: BitrateType, peerConnection: WRKRTCPeerConnection) async {
        
        let adjustmentTracker = getAdjustmentTracker(for: type)
        let networkDataCache = getNetworkDataCache(for: type)
        
        guard
            !(await adjustmentTracker.isInCoolDown()),
            let packetLoss = await networkDataCache.getPacketLossRate(overLast: 10)
        else { return }
        
        await adjustBitrate(
            for: type,
            peerConnection: peerConnection,
            packetLoss: packetLoss,
            handleCriticalPacketLoss: false
        )
    }
}
