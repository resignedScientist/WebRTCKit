import WebRTC
import CallKit
import AVKit

#warning("TODO: remove all unchecked sendables")

extension RTCVideoCapturer: @unchecked @retroactive Sendable {}

extension CXCallAction: @unchecked @retroactive Sendable {}

extension CXCallController: @unchecked @retroactive Sendable {}

extension CXProvider: @unchecked @retroactive Sendable {}

extension AVCaptureDevice.Format: @unchecked @retroactive Sendable {}

extension RTCRtpSender: @unchecked @retroactive Sendable {}
