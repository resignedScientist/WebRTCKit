import Foundation
import WebRTC

/// An enumeration representing the type of stream for the bitrate to adjust.
enum BitrateType: String, Equatable {
    
    /// Case representing the audio stream.
    case audio
    
    /// Case representing the video stream.
    case video
}

/// A protocol defining methods to adjust and manage bitrate settings for peer connections.
@WebRTCActor
protocol BitrateAdjustor {
    
    /// Starts adjusting the bitrate for a specific type.
    /// - Parameters:
    ///   - type: The type of bitrate adjustment to start.
    ///   - peerConnection: The peer connection on which to adjust the bitrate.
    func start(for type: BitrateType, peerConnection: WRKRTCPeerConnection)
    
    /// Stops all bitrate adjustments.
    func stop() async
    
    /// Stops adjusting the bitrate for a specific type.
    /// - Parameter type: The type of bitrate adjustment to stop.
    func stop(for type: BitrateType) async
    
    /// Sets the initial encoding parameters for a specific type.
    /// - Parameters:
    ///   - type: The type of bitrate for which to set the initial encoding parameters.
    ///   - peerConnection: The peer connection on which to set the encoding parameters.
    func setStartEncodingParameters(for type: BitrateType, peerConnection: WRKRTCPeerConnection)
}

final class BitrateAdjustorImpl: BitrateAdjustor {
    
    @Inject(\.config) private var config
    
    private let audioAdjustmentTracker: AdjustmentTracker = AdjustmentTrackerImpl(cooldownDuration: 3)
    private let videoAdjustmentTracker: AdjustmentTracker = AdjustmentTrackerImpl(cooldownDuration: 3)
    private let audioNetworkDataCache: NetworkDataCache = NetworkDataCacheImpl()
    private let videoNetworkDataCache: NetworkDataCache = NetworkDataCacheImpl()
    private let log = Logger(caller: "BitrateAdjustor")
    private var slowTimer: DispatchSourceTimer?
    private var fastTimer: DispatchSourceTimer?
    
    private var runningTypes: Set<BitrateType> = []
    
    func start(for type: BitrateType, peerConnection: WRKRTCPeerConnection) {
        guard !runningTypes.contains(type) else { return }
        
        runningTypes.insert(type)
        
        if slowTimer == nil || fastTimer == nil {
            registerStatisticObservers(peerConnection: peerConnection)
        }
        
        log.info("Started for \(type)")
    }
    
    func stop() async {
        fastTimer?.cancel()
        slowTimer?.cancel()
        fastTimer = nil
        slowTimer = nil
        runningTypes.removeAll()
        await audioNetworkDataCache.deleteAllData()
        await videoNetworkDataCache.deleteAllData()
        log.info("Stopped")
    }
    
    func stop(for type: BitrateType) async {
        guard runningTypes.contains(type) else { return }
        
        runningTypes.remove(type)
        
        // delete cached network data for that type
        switch type {
        case .audio:
            await audioNetworkDataCache.deleteAllData()
        case .video:
            await videoNetworkDataCache.deleteAllData()
        }
        
        // stop all timers if nothing is running anymore
        if runningTypes.isEmpty {
            log.info("Stopping timers…")
            fastTimer?.cancel()
            slowTimer?.cancel()
            fastTimer = nil
            slowTimer = nil
        }
        
        log.info("Stopped for \(type)")
    }
    
    func setStartEncodingParameters(for type: BitrateType, peerConnection: any WRKRTCPeerConnection) {
        
        log.info("Setting start encoding parameters for \(type)")
        
        switch type {
        case .audio:
            setStartAudioEncodingParameters(peerConnection)
        case .video:
            setStartVideoEncodingParameters(peerConnection)
        }
    }
}

// MARK: - Private functions

private extension BitrateAdjustorImpl {
    
    func registerStatisticObservers(peerConnection: WRKRTCPeerConnection) {
        
        // fast task (every second)
        let fastTimer = DispatchSource.makeTimerSource(queue: WebRTCActor.queue)
        fastTimer.setEventHandler { [weak self] in
            Task { @WebRTCActor in
                await withDiscardingTaskGroup { taskGroup in
                    
                    // video
                    taskGroup.addTask { [weak self] in
                        await self?.runFastTask(for: .video, peerConnection: peerConnection)
                    }
                    
                    // audio
                    taskGroup.addTask { [weak self] in
                        await self?.runFastTask(for: .audio, peerConnection: peerConnection)
                    }
                }
            }
        }
        fastTimer.schedule(deadline: .now(), repeating: .seconds(1))
        fastTimer.resume()
        self.fastTimer = fastTimer
        
        // slow task (every 5 seconds)
        let slowTimer = DispatchSource.makeTimerSource(queue: WebRTCActor.queue)
        slowTimer.setEventHandler { [weak self] in
            Task { @WebRTCActor in
                await withDiscardingTaskGroup { taskGroup in
                    
                    // video
                    taskGroup.addTask { [weak self] in
                        await self?.runSlowTask(for: .video, peerConnection: peerConnection)
                    }
                    
                    // audio
                    taskGroup.addTask { [weak self] in
                        await self?.runSlowTask(for: .audio, peerConnection: peerConnection)
                    }
                }
            }
        }
        slowTimer.schedule(deadline: .now(), repeating: .seconds(5))
        slowTimer.resume()
        self.slowTimer = slowTimer
        
        log.info("Timers started")
    }
    
    func fetchStats(peerConnection: WRKRTCPeerConnection, for type: BitrateType) async -> NetworkDataPoint? {
        let report = await peerConnection.statistics()
        
        guard !report.statistics.isEmpty else { return nil }
        
        var packetsLost: Int?
        var packetsSent: Int?
        
        for stats in report.statistics.values {
            guard stats.kind == type else { continue }
            
            if stats.type == .remoteInboundRtp {
                guard let lost = stats.packetsLost else { continue }
                packetsLost = lost
            } else if stats.type == .outboundRtp {
                guard let sent = stats.packetsSent else { continue }
                packetsSent = sent
            }
            
            // break the loop if both values have been found
            if packetsLost != nil && packetsSent != nil {
                break
            }
        }
        
        guard let packetsLost, let packetsSent else { return nil }
        
        log.info("Fetched stats")
        
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
        else {
            return
        }
        
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
            log.info("Adjusted video bitrate to \(bitrate) with scaling factor \(scalingFactor).")
        } else {
            log.info("Adjusted audio bitrate to \(bitrate).")
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
    
    func getConfig(for type: BitrateType) -> BitrateConfig {
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
        guard
            runningTypes.contains(type),
            let dataPoint = await fetchStats(
                peerConnection: peerConnection,
                for: type
            )
        else { return }
        
        log.info("Running fast task…")
        
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
        
        guard runningTypes.contains(type) else { return }
        
        log.info("Running slow task…")
        
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
    
    func setStartAudioEncodingParameters(_ peerConnection: WRKRTCPeerConnection) {
        guard let audioSender = peerConnection.senders
            .first(where: { $0.track?.kind == BitrateType.audio.rawValue })
        else { return }
        
        let encoding = audioSender.parameters.encodings.first ?? RTCRtpEncodingParameters()
        let parameters = audioSender.parameters
        encoding.minBitrateBps = NSNumber(value: config.audio.minBitrate)
        encoding.maxBitrateBps = NSNumber(value: config.audio.startBitrate)
        parameters.encodings = [encoding]
        audioSender.parameters = parameters
    }
    
    func setStartVideoEncodingParameters(_ peerConnection: WRKRTCPeerConnection) {
        guard
            let videoSender = peerConnection.senders
                .first(where: { $0.track?.kind == BitrateType.video.rawValue })
        else { return }
        
        let encoding = videoSender.parameters.encodings.first ?? RTCRtpEncodingParameters()
        let parameters = videoSender.parameters
        encoding.minBitrateBps = NSNumber(value: config.video.minBitrate)
        encoding.maxBitrateBps = NSNumber(value: config.video.startBitrate)
        encoding.maxFramerate = 30
        encoding.scaleResolutionDownBy = calculateVideoScaling(for: config.video.startBitrate)
        parameters.encodings = [encoding]
        videoSender.parameters = parameters
    }
}
