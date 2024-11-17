import WebRTC
import CallKit
import AVKit

#warning("TODO: remove all unchecked sendables")

extension CXCallAction: @unchecked @retroactive Sendable {}

extension CXCallController: @unchecked @retroactive Sendable {}

extension CXProvider: @unchecked @retroactive Sendable {}

extension AVCaptureDevice.Format: @unchecked @retroactive Sendable {}
