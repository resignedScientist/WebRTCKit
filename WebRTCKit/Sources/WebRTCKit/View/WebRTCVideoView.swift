import SwiftUI
import WebRTC

public struct WebRTCVideoView: View {
    
    @State private var aspectRatio: CGFloat = 9/16
    
    private let videoTrack: RTCVideoTrack?
    private let source: MediaTrackSource
    private let aspectFit: Bool
    private let isMirrored: Bool
    
    public init(
        videoTrack: RTCVideoTrack?,
        source: MediaTrackSource,
        aspectFit: Bool = true,
        isMirrored: Bool = false
    ) {
        self.videoTrack = videoTrack
        self.source = source
        self.aspectFit = aspectFit
        self.isMirrored = isMirrored
    }
    
    public var body: some View {
        Group {
            if aspectFit {
                Group {
                    if let videoTrack {
                        WebRTCView(
                            videoTrack: videoTrack,
                            source: source,
                            aspectRatio: $aspectRatio
                        )
                    } else {
                        Color.clear
                    }
                }
                .aspectRatio(aspectFit ? aspectRatio : nil, contentMode: .fit)
                .animation(.default, value: aspectRatio)
            } else {
                Group {
                    if let videoTrack {
                        WebRTCView(
                            videoTrack: videoTrack,
                            source: source,
                            aspectRatio: $aspectRatio
                        )
                    } else {
                        Color.clear
                    }
                }
            }
        }
        .scaleEffect(x: isMirrored ? -1 : 1)
    }
}

private struct WebRTCView: UIViewRepresentable {
    
    let videoTrack: RTCVideoTrack
    let source: MediaTrackSource
    @Binding var aspectRatio: CGFloat
    
    func makeCoordinator() -> Coordinator {
        Coordinator(aspectRatio: $aspectRatio, source: source)
    }

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let videoView = RTCMTLVideoView()
        videoView.videoContentMode = .scaleAspectFill
        videoView.delegate = context.coordinator
        return videoView
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        videoTrack.add(uiView)
        context.coordinator.source = source
    }
}

private extension WebRTCView {
    
    @MainActor
    final class Coordinator {
        @Binding var aspectRatio: CGFloat
        var source: MediaTrackSource
        
        private let log = Logger(caller: "WebRTCVideoView", category: .userInterface)
        
        init(aspectRatio: Binding<CGFloat>, source: MediaTrackSource) {
            _aspectRatio = aspectRatio
            self.source = source
        }
    }
}

// MARK: - RTCVideoViewDelegate

extension WebRTCView.Coordinator: @MainActor RTCVideoViewDelegate {
    
    func videoView(_ videoView: any RTCVideoRenderer, didChangeVideoSize size: CGSize) {
        log.info("\(source) video stream did change video size to \(size)")
        aspectRatio = size.width / size.height
    }
}
