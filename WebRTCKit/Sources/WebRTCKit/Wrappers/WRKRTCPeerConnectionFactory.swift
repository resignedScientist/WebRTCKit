import WebRTC

@WebRTCActor
protocol WRKRTCPeerConnectionFactory: AnyObject {
    
    func peerConnection(
        with configuration: RTCConfiguration,
        constraints: RTCMediaConstraints,
        delegate: WRKRTCPeerConnectionDelegate?
    ) -> WRKRTCPeerConnection?
    
    func videoSource() -> WRKRTCVideoSource
    
    func videoTrack(with videoSource: WRKRTCVideoSource, trackId: String) -> WRKRTCVideoTrack
    
    func audioSource(with constraints: RTCMediaConstraints?) -> WRKRTCAudioSource
    
    func audioTrack(with audioSource: WRKRTCAudioSource, trackId: String) -> WRKRTCAudioTrack
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
    
    func videoSource() -> WRKRTCVideoSource {
        WRKRTCVideoSourceImpl(
            factory.videoSource()
        )
    }
    
    func videoTrack(with videoSource: WRKRTCVideoSource, trackId: String) -> WRKRTCVideoTrack {
        if let videoSource = (videoSource as? WRKRTCVideoSourceImpl)?.videoSource {
            return WRKRTCVideoTrackImpl(
                factory.videoTrack(with: videoSource, trackId: trackId)
            )
        }
        fatalError("Mixing mock videoSource with prod PeerConnectionFactory")
    }
    
    func audioSource(with constraints: RTCMediaConstraints?) -> WRKRTCAudioSource {
        WRKRTCAudioSourceImpl(
            factory.audioSource(with: constraints)
        )
    }
    
    func audioTrack(with audioSource: WRKRTCAudioSource, trackId: String) -> WRKRTCAudioTrack {
        if let audioSource = (audioSource as? WRKRTCAudioSourceImpl)?.audioSource {
            return WRKRTCAudioTrackImpl(
                factory.audioTrack(with: audioSource, trackId: trackId)
            )
        }
        fatalError("Mixing mock audioSource with prod PeerConnectionFactory")
    }
}
