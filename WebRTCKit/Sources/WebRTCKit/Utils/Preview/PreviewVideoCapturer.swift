import WebRTC
import AVKit

enum PreviewVideoCapturerError: Error {
    case assetNotFound
}

// AVAsset must run on the main actor and is not Sendable.
// So we have to let everything here run on the main actor.
@MainActor
final class PreviewVideoCapturer: RTCVideoCapturer, Sendable {
    
    private lazy var asset: AVAsset? = {
        guard
            let path = Bundle.main.path(forResource: "example", ofType: "mp4")
        else { return nil }
        let url = URL(fileURLWithPath: path)
        return AVURLAsset(url: url)
    }()
    
    private var isRunning = false
    private var player: AVPlayer?
    private var videoOutput: AVPlayerItemVideoOutput?
    private let playerOutputQueue = DispatchQueue(label: "com.webrtckit.player.output")
    
    func start() async throws(PreviewVideoCapturerError) {
        guard !isRunning else { return }
        isRunning = true
        try await startReadingAsset()
    }
    
    func stop() {
        guard isRunning else { return }
        isRunning = false
        player?.pause()
        player = nil
        videoOutput = nil
    }
}

// MARK: - Private functions

private extension PreviewVideoCapturer {
    
    func startReadingAsset() async throws(PreviewVideoCapturerError) {
        
        guard
            let asset,
            let videoTrack = asset.tracks(withMediaType: .video).first
        else {
            throw .assetNotFound
        }
        
        let videoSize = videoTrack.naturalSize
        let videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferWidthKey as String: videoSize.width,
            kCVPixelBufferHeightKey as String: videoSize.height
        ])
        let playerItem = AVPlayerItem(asset: asset)
        
        playerItem.add(videoOutput)
        
        let player = AVPlayer(playerItem: playerItem)
        player.actionAtItemEnd = .none
        
        // Observe end of playback to loop video
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        // add periodic timer to capture frames
        let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.addPeriodicTimeObserver(forInterval: interval, queue: playerOutputQueue) { [weak self] currentTime in
            Task { @MainActor [weak self] in
                self?.captureFrame(at: currentTime)
            }
        }
        
        self.videoOutput = videoOutput
        self.player = player
        
        player.play()
    }
    
    @objc func playerItemDidReachEnd() {
        player?.seek(to: .zero)
        player?.play()
    }
    
    func captureFrame(at time: CMTime) {
        
        guard let videoOutput else { return }
        
        let itemTime = videoOutput.itemTime(forHostTime: CACurrentMediaTime())
        
        guard
            videoOutput.hasNewPixelBuffer(forItemTime: itemTime),
            let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil)
        else { return }
        
        let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
        let timeStampNs = CMTimeGetSeconds(itemTime) * Double(NSEC_PER_SEC)
        let videoFrame = RTCVideoFrame(
            buffer: rtcPixelBuffer,
            rotation: ._0,
            timeStampNs: Int64(timeStampNs)
        )
        
        let imageSize = CIImage(cvImageBuffer: pixelBuffer).extent.size
        
        // Send the frame to WebRTC
        delegate?.capturer(self, didCapture: videoFrame)
    }
}
