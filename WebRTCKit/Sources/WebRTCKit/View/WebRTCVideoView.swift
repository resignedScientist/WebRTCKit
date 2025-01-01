import SwiftUI
import WebRTC

public struct WebRTCVideoView: View {
    
    @State private var aspectRatio: CGFloat = 9/16
    
    private let videoTrack: WRKRTCVideoTrack?
    private let aspectFit: Bool
    
    public init(videoTrack: WRKRTCVideoTrack?, aspectFit: Bool = true) {
        self.videoTrack = videoTrack
        self.aspectFit = aspectFit
    }
    
    public var body: some View {
        if aspectFit {
            Group {
                if let videoTrack {
                    WebRTCView(videoTrack: videoTrack, aspectRatio: $aspectRatio)
                } else {
                    Color.clear
                }
            }
            .aspectRatio(aspectFit ? aspectRatio : nil, contentMode: .fit)
            .animation(.default, value: aspectRatio)
        } else {
            Group {
                if let videoTrack {
                    WebRTCView(videoTrack: videoTrack, aspectRatio: $aspectRatio)
                } else {
                    Color.clear
                }
            }
        }
    }
}

private struct WebRTCView: UIViewRepresentable {
    
    let videoTrack: WRKRTCVideoTrack
    @Binding var aspectRatio: CGFloat
    
    func makeCoordinator() -> Coordinator {
        Coordinator(aspectRatio: $aspectRatio, source: videoTrack.source)
    }

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let videoView = RTCMTLVideoView()
        videoView.videoContentMode = .scaleAspectFill
        videoView.delegate = context.coordinator
        return videoView
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        videoTrack.add(uiView)
        context.coordinator.source = videoTrack.source
    }
}

private extension WebRTCView {
    
    class Coordinator {
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

extension WebRTCView.Coordinator: RTCVideoViewDelegate {
    
    func videoView(_ videoView: any RTCVideoRenderer, didChangeVideoSize size: CGSize) {
        log.info("\(source) video stream did change video size to \(size)")
        aspectRatio = size.width / size.height
    }
}
