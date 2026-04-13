import WebRTC

@MainActor
protocol WRKRTCPeerConnectionFactory: AnyObject {
    
    func peerConnection(
        with configuration: RTCConfiguration,
        constraints: RTCMediaConstraints,
        delegate: WRKRTCPeerConnectionDelegate?
    ) -> WRKRTCPeerConnection?
    
    func videoSource() -> RTCVideoSource
    
    func videoTrack(with videoSource: RTCVideoSource, trackId: String) -> RTCVideoTrack
    
    func audioSource(with constraints: RTCMediaConstraints?) -> RTCAudioSource
    
    func audioTrack(with audioSource: RTCAudioSource, trackId: String) -> RTCAudioTrack
}

final class WRKRTCPeerConnectionFactoryImpl: WRKRTCPeerConnectionFactory {
    
    let factory: RTCPeerConnectionFactory
    
    init(audioDevice: RTCAudioDevice? = nil) {
        factory = RTCPeerConnectionFactory(
            encoderFactory: RTCVideoEncoderFactoryH264(),
            decoderFactory: RTCVideoDecoderFactoryH264(),
            audioDevice: audioDevice
        )
    }
    
    func peerConnection(
        with configuration: RTCConfiguration,
        constraints: RTCMediaConstraints,
        delegate: WRKRTCPeerConnectionDelegate?
    ) -> WRKRTCPeerConnection? {
        if let peerConnection = factory.peerConnection(
            with: configuration,
            constraints: constraints,
            delegate: nil // will be assigned in wrappers init
        ) {
            return WRKRTCPeerConnectionImpl(peerConnection, delegate: delegate)
        }
        return nil
    }
    
    func videoSource() -> RTCVideoSource {
        factory.videoSource()
    }
    
    func videoTrack(with videoSource: RTCVideoSource, trackId: String) -> RTCVideoTrack {
        factory.videoTrack(with: videoSource, trackId: trackId)
    }
    
    func audioSource(with constraints: RTCMediaConstraints?) -> RTCAudioSource {
        factory.audioSource(with: constraints)
    }
    
    func audioTrack(with audioSource: RTCAudioSource, trackId: String) -> RTCAudioTrack {
        factory.audioTrack(with: audioSource, trackId: trackId)
    }
}
