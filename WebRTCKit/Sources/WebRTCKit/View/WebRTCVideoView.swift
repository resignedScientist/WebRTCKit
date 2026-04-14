import SwiftUI
import WebRTC

public struct WebRTCVideoView: View {
    
    @State private var aspectRatio: CGFloat = 9/16
    
    private let source: MediaTrackSource
    private let aspectFit: Bool
    private let isMirrored: Bool
    
    public init(
        source: MediaTrackSource,
        aspectFit: Bool = true,
        isMirrored: Bool = false
    ) {
        self.source = source
        self.aspectFit = aspectFit
        self.isMirrored = isMirrored
    }
    
    public var body: some View {
        Group {
            if aspectFit {
                WebRTCView(
                    source: source,
                    aspectRatio: $aspectRatio
                )
                .aspectRatio(aspectFit ? aspectRatio : nil, contentMode: .fit)
                .animation(.default, value: aspectRatio)
            } else {
                WebRTCView(
                    source: source,
                    aspectRatio: $aspectRatio
                )
            }
        }
        .scaleEffect(x: isMirrored ? -1 : 1)
    }
}

private struct WebRTCView: UIViewRepresentable {
    
    let source: MediaTrackSource
    @Binding var aspectRatio: CGFloat
    
    func makeCoordinator() -> Coordinator {
        Coordinator(aspectRatio: $aspectRatio)
    }

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let videoView = RTCMTLVideoView()
        videoView.videoContentMode = .scaleAspectFill
        videoView.delegate = context.coordinator
        return videoView
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        context.coordinator.loadVideoTrack(into: uiView, source: source)
    }
    
    static func dismantleUIView(_ uiView: RTCMTLVideoView, coordinator: Coordinator) {
        coordinator.dismandle()
    }
}

private extension WebRTCView {
    
    struct VideoSetup {
        let source: MediaTrackSource
        let delegateHandle: UUID
        let videoView: RTCMTLVideoView
    }
    
    @MainActor
    final class Coordinator {
        @Binding var aspectRatio: CGFloat
        private var currentSetup: VideoSetup?
        
        @Inject(\.webRTCManager) private var webRTCManager
        
        private let log = Logger(caller: "WebRTCVideoView", category: .userInterface)
        
        init(aspectRatio: Binding<CGFloat>) {
            _aspectRatio = aspectRatio
        }
        
        func dismandle() {
            if let delegateHandle = currentSetup?.delegateHandle {
                webRTCManager.removeVideoTrackDelegate(delegateHandle)
            }
        }
        
        func loadVideoTrack(into videoView: RTCMTLVideoView, source: MediaTrackSource) {
            
            // remove the old delegate
            if let delegateHandle = currentSetup?.delegateHandle {
                webRTCManager.removeVideoTrackDelegate(delegateHandle)
            }
            
            // add the new delegate
            let delegateHandle = webRTCManager.addVideoTrackDelegate(self)
            
            // save the new video setup
            currentSetup = VideoSetup(
                source: source,
                delegateHandle: delegateHandle,
                videoView: videoView
            )
        }
    }
}

// MARK: - WebRTCKitVideoTrackDelegate

extension WebRTCView.Coordinator: WebRTCKitVideoTrackDelegate {
    
    func didAddLocalVideoTrack(_ videoTrack: RTCVideoTrack) {
        guard
            let currentSetup,
            currentSetup.source == .local
        else { return }
        
        videoTrack.add(currentSetup.videoView)
    }
    
    func didAddRemoteVideoTrack(_ videoTrack: RTCVideoTrack) {
        guard
            let currentSetup,
            currentSetup.source == .remote
        else { return }
        
        videoTrack.add(currentSetup.videoView)
    }
    
    func didRemoveRemoteVideoTrack(_ videoTrack: RTCVideoTrack) {
        guard
            let currentSetup,
            currentSetup.source == .remote
        else { return }
        
        videoTrack.remove(currentSetup.videoView)
    }
}

// MARK: - RTCVideoViewDelegate

extension WebRTCView.Coordinator: @MainActor RTCVideoViewDelegate {
    
    func videoView(_ videoView: any RTCVideoRenderer, didChangeVideoSize size: CGSize) {
        if let source = currentSetup?.source {
            log.info("\(source) video stream did change video size to \(size)")
        }
        aspectRatio = size.width / size.height
    }
}
