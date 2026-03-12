import AVFoundation
import SwiftUI

private struct ScaleHeight: ViewModifier {
  let scale: CGFloat
  func body(content: Content) -> some View {
    content.scaleEffect(x: 1.0, y: scale, anchor: .top)
  }
}

private extension AnyTransition {
  nonisolated(unsafe) static let trackTransition: AnyTransition = .opacity.combined(
    with: .modifier(
      active: ScaleHeight(scale: 0.01),
      identity: ScaleHeight(scale: 1.0)
    )
  )
}

struct TimelineView: View {
  @Bindable var editorState: EditorState
  let systemAudioSamples: [Float]
  let micAudioSamples: [Float]
  var systemAudioProgress: Double?
  var micAudioProgress: Double?
  var micAudioMessage: String?
  let onScrub: (CMTime) -> Void
  @Binding var timelineZoom: CGFloat
  @Binding var baseZoom: CGFloat
  @Environment(\.colorScheme) private var colorScheme

  let sidebarWidth: CGFloat = 70
  let rulerHeight: CGFloat = Layout.rulerHeight
  private let playheadInset: CGFloat = 7
  let trackHeight: CGFloat = Track.height

  @State var scrollOffset: CGFloat = 0
  @State private var scrollPosition = ScrollPosition(edge: .leading)

  var totalSeconds: Double {
    max(CMTimeGetSeconds(editorState.duration), 0.001)
  }

  private var playheadFraction: Double {
    CMTimeGetSeconds(editorState.currentTime) / totalSeconds
  }

  private var videoTrimStart: Double {
    CMTimeGetSeconds(editorState.trimStart) / totalSeconds
  }

  private var videoTrimEnd: Double {
    CMTimeGetSeconds(editorState.trimEnd) / totalSeconds
  }

  @State var audioDragOffset: CGFloat = 0
  @State var audioDragType: RegionDragType?
  @State var audioDragRegionId: UUID?

  @State var cameraDragOffset: CGFloat = 0
  @State var cameraDragType: RegionDragType?
  @State var cameraDragRegionId: UUID?
  @State var popoverCameraRegionId: UUID?

  @State var videoDragOffset: CGFloat = 0
  @State var videoDragType: RegionDragType?
  @State var videoDragRegionId: UUID?
  @State var popoverVideoRegionId: UUID?

  @State var spotlightDragOffset: CGFloat = 0
  @State var spotlightDragType: RegionDragType?
  @State var spotlightDragRegionId: UUID?
  @State var popoverSpotlightRegionId: UUID?

  private var showSystemAudioTrack: Bool {
    !editorState.systemAudioMuted
      && (!systemAudioSamples.isEmpty || editorState.hasSystemAudio)
  }

  private var showMicAudioTrack: Bool {
    !editorState.micAudioMuted
      && ((!micAudioSamples.isEmpty && !editorState.isMicProcessing) || editorState.hasMicAudio)
  }

  private var showSpotlightTrack: Bool {
    editorState.spotlightEnabled && editorState.cursorMetadataProvider != nil
  }

  private var visibleTrackCount: Int {
    var count = 1
    if editorState.hasWebcam && editorState.webcamEnabled { count += 1 }
    if showSystemAudioTrack { count += 1 }
    if showMicAudioTrack { count += 1 }
    if editorState.zoomEnabled { count += 1 }
    if showSpotlightTrack { count += 1 }
    return count
  }

  var timelineHeight: CGFloat {
    let n = CGFloat(visibleTrackCount)
    return rulerHeight + 8 + n * trackHeight + max(0, n - 1) * 10
  }

  var body: some View {
    let _ = colorScheme
    HStack(spacing: 0) {
      VStack(spacing: 8) {
        Color.clear.frame(height: rulerHeight)
        VStack(spacing: 10) {
          trackSidebar(label: "Screen", icon: "display")
            .frame(height: trackHeight)

          if editorState.hasWebcam && editorState.webcamEnabled {
            trackSidebar(label: "Camera", icon: "web.camera")
              .frame(height: trackHeight)
              .transition(.trackTransition)
          }

          if showSystemAudioTrack {
            trackSidebar(label: "System", icon: "speaker.wave.2")
              .frame(height: trackHeight)
              .transition(.trackTransition)
          }

          if showMicAudioTrack {
            trackSidebar(label: "Mic", icon: "mic")
              .frame(height: trackHeight)
              .transition(.trackTransition)
          }

          if editorState.zoomEnabled {
            trackSidebar(label: "Zoom", icon: "plus.magnifyingglass")
              .frame(height: trackHeight)
              .transition(.trackTransition)
          }

          if showSpotlightTrack {
            trackSidebar(label: "Spotlight", icon: "light.max")
              .frame(height: trackHeight)
              .transition(.trackTransition)
          }
        }
      }
      .frame(width: sidebarWidth)

      GeometryReader { geo in
        let availableWidth = geo.size.width - playheadInset * 2
        let cw = availableWidth * timelineZoom
        let frameWidth = cw + playheadInset * 2

        ScrollView(.horizontal, showsIndicators: false) {
          ZStack(alignment: .top) {
            VStack(spacing: 8) {
              timeRuler(width: cw)

              VStack(spacing: 10) {
                screenTrackContent(width: cw)

                if editorState.hasWebcam && editorState.webcamEnabled {
                  cameraTrackContent(width: cw)
                    .transition(.trackTransition)
                }

                if showSystemAudioTrack {
                  Group {
                    if !systemAudioSamples.isEmpty {
                      audioTrackContent(
                        trackType: .system,
                        samples: systemAudioSamples,
                        width: cw
                      )
                    } else {
                      audioLoadingContent(
                        progress: systemAudioProgress ?? 0,
                        width: cw
                      )
                    }
                  }
                  .transition(.trackTransition)
                }

                if showMicAudioTrack {
                  Group {
                    if !micAudioSamples.isEmpty && !editorState.isMicProcessing {
                      audioTrackContent(
                        trackType: .mic,
                        samples: micAudioSamples,
                        width: cw
                      )
                    } else {
                      audioLoadingContent(
                        progress: micAudioProgress ?? 0,
                        message: micAudioMessage,
                        width: cw
                      )
                    }
                  }
                  .transition(.trackTransition)
                }

                if editorState.zoomEnabled {
                  zoomTrackContent(width: cw, keyframes: editorState.zoomTimeline?.allKeyframes ?? [])
                    .transition(.trackTransition)
                }

                if showSpotlightTrack {
                  spotlightTrackContent(width: cw)
                    .transition(.trackTransition)
                }
              }
            }
            .padding(.horizontal, playheadInset)
            .padding(.bottom, timelineZoom > 1 ? 10 : 0)

            playheadOverlay(contentWidth: cw, inset: playheadInset)
          }
          .frame(width: frameWidth)
        }
        .scrollPosition($scrollPosition)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
          geometry.contentOffset.x
        } action: { _, newValue in
          scrollOffset = newValue
        }
        .scrollIndicators(timelineZoom > 1 ? .visible : .hidden)
        .overlay {
          CmdScrollZoomOverlay { delta, cursorX in
            let oldZoom = timelineZoom
            let factor = 1.0 + delta * 0.03
            let newZoom = max(1.0, min(30.0, oldZoom * factor))
            guard newZoom != oldZoom else { return }

            let oldCw = availableWidth * oldZoom
            let cursorInContent = scrollOffset + cursorX
            let trackFraction = (cursorInContent - playheadInset) / oldCw

            let newCw = availableWidth * newZoom
            let newCursorInContent = playheadInset + trackFraction * newCw
            let newOffset = max(0, newCursorInContent - cursorX)

            timelineZoom = newZoom
            baseZoom = newZoom
            scrollPosition.scrollTo(point: CGPoint(x: newOffset, y: 0))
          }
        }
        .gesture(
          MagnifyGesture()
            .onChanged { value in
              timelineZoom = max(1.0, min(30.0, baseZoom * value.magnification))
            }
            .onEnded { _ in
              baseZoom = timelineZoom
            }
        )
      }
      .padding(.trailing, 8)
    }
    .frame(height: timelineHeight)
    .animation(.easeInOut(duration: 0.2), value: visibleTrackCount)
    .background(ReframedColors.backgroundCard)
    .padding(.vertical, 8)
  }

}
