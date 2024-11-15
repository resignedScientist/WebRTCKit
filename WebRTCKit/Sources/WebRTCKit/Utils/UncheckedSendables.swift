import WebRTC
import CallKit
import AVKit

#warning("TODO: remove all unchecked sendables")

extension RTCVideoCapturer: @unchecked @retroactive Sendable {}

extension RTCSessionDescription: @unchecked @retroactive Sendable {}

extension RTCIceServer: @unchecked @retroactive Sendable {}

extension CXCallAction: @unchecked @retroactive Sendable {}

extension RTCRtpSender: @unchecked @retroactive Sendable {}

extension RTCIceCandidate: @unchecked @retroactive Sendable {}

extension CXCallController: @unchecked @retroactive Sendable {}

extension CXProvider: @unchecked @retroactive Sendable {}

extension RTCDataChannel: @unchecked @retroactive Sendable {}

extension RTCMediaStream: @unchecked @retroactive Sendable {}

extension RTCAudioSession: @unchecked @retroactive Sendable {}

extension RTCAudioTrack: @unchecked @retroactive Sendable {}

extension RTCPeerConnectionState: @unchecked @retroactive Sendable {}

extension RTCMediaConstraints: @unchecked @retroactive Sendable {}

extension RTCPeerConnection: @unchecked @retroactive Sendable {}

extension RTCVideoTrack: @unchecked @retroactive Sendable {}

extension RTCDataChannelConfiguration: @unchecked @retroactive Sendable {}

extension AVCaptureDevice.Format: @unchecked @retroactive Sendable {}

extension RTCStatisticsReport: @unchecked @retroactive Sendable {}

extension CXCallUpdate: @unchecked @retroactive Sendable {}
