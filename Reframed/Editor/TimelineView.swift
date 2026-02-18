import AVFoundation
import SwiftUI

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
  private let rulerHeight: CGFloat = 32
  private let playheadInset: CGFloat = 7
  let trackHeight: CGFloat = 32

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

  private var showSystemAudioTrack: Bool {
    !systemAudioSamples.isEmpty || editorState.hasSystemAudio
  }

  private var showMicAudioTrack: Bool {
    (!micAudioSamples.isEmpty && !editorState.isMicProcessing) || editorState.hasMicAudio
  }

  private var visibleTrackCount: Int {
    var count = 1
    if editorState.hasWebcam { count += 1 }
    if showSystemAudioTrack { count += 1 }
    if showMicAudioTrack { count += 1 }
    if editorState.zoomEnabled { count += 1 }
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

          if editorState.hasWebcam {
            trackSidebar(label: "Camera", icon: "web.camera")
              .frame(height: trackHeight)
          }

          if showSystemAudioTrack {
            trackSidebar(label: "System", icon: "speaker.wave.2")
              .frame(height: trackHeight)
          }

          if showMicAudioTrack {
            trackSidebar(label: "Mic", icon: "mic")
              .frame(height: trackHeight)
          }

          if editorState.zoomEnabled {
            trackSidebar(label: "Zoom", icon: "plus.magnifyingglass")
              .frame(height: trackHeight)
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

                if editorState.hasWebcam {
                  cameraTrackContent(width: cw)
                }

                if !systemAudioSamples.isEmpty {
                  audioTrackContent(
                    trackType: .system,
                    samples: systemAudioSamples,
                    accentColor: ReframedColors.systemAudioColor,
                    width: cw
                  )
                } else if editorState.hasSystemAudio {
                  audioLoadingContent(
                    progress: systemAudioProgress ?? 0,
                    accentColor: ReframedColors.systemAudioColor,
                    width: cw
                  )
                }

                if !micAudioSamples.isEmpty && !editorState.isMicProcessing {
                  audioTrackContent(
                    trackType: .mic,
                    samples: micAudioSamples,
                    accentColor: ReframedColors.micAudioColor,
                    width: cw
                  )
                } else if editorState.hasMicAudio {
                  audioLoadingContent(
                    progress: micAudioProgress ?? 0,
                    message: micAudioMessage,
                    accentColor: ReframedColors.micAudioColor,
                    width: cw
                  )
                }

                if editorState.zoomEnabled {
                  zoomTrackContent(width: cw, keyframes: editorState.zoomTimeline?.allKeyframes ?? [])
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
    .background(ReframedColors.panelBackground)
    .padding(.vertical, 8)
  }

  private func timeRuler(width: CGFloat) -> some View {
    Canvas { context, size in
      let duration = totalSeconds
      let interval = rulerInterval(for: duration)
      let minorInterval = interval / 5

      var t: Double = 0
      while t <= duration {
        let x = CGFloat(t / duration) * size.width
        let isMajor = isApproximatelyMultiple(t, of: interval)

        if isMajor {
          let tickPath = Path { p in
            p.move(to: CGPoint(x: x, y: size.height - 10))
            p.addLine(to: CGPoint(x: x, y: size.height))
          }
          context.stroke(tickPath, with: .color(ReframedColors.primaryText), lineWidth: 1)

          let label = formatRulerTime(t)
          let text = Text(label)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(ReframedColors.primaryText)
          context.draw(context.resolve(text), at: CGPoint(x: x, y: size.height - 16), anchor: .bottom)
        } else {
          let tickPath = Path { p in
            p.move(to: CGPoint(x: x, y: size.height - 5))
            p.addLine(to: CGPoint(x: x, y: size.height))
          }
          context.stroke(tickPath, with: .color(ReframedColors.primaryText.opacity(0.5)), lineWidth: 0.5)
        }
        t += minorInterval
      }
    }
    .frame(width: width, height: rulerHeight)
    .background(ReframedColors.panelBackground)
    .contentShape(Rectangle())
    .gesture(rulerScrubGesture(width: width))
  }

  private func rulerInterval(for duration: Double) -> Double {
    let effectiveDuration = duration / timelineZoom
    if effectiveDuration <= 5 { return 1 }
    if effectiveDuration <= 15 { return 2 }
    if effectiveDuration <= 30 { return 5 }
    if effectiveDuration <= 60 { return 10 }
    if effectiveDuration <= 180 { return 30 }
    if effectiveDuration <= 600 { return 60 }
    return 120
  }

  private func isApproximatelyMultiple(_ value: Double, of interval: Double) -> Bool {
    let remainder = value.truncatingRemainder(dividingBy: interval)
    return remainder < 0.001 || (interval - remainder) < 0.001
  }

  private func formatRulerTime(_ seconds: Double) -> String {
    let mins = Int(seconds) / 60
    let secs = Int(seconds) % 60
    if totalSeconds >= 60 {
      return String(format: "%d:%02d", mins, secs)
    }
    return String(format: "0:%02d", secs)
  }

  private func rulerScrubGesture(width: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        let fraction = max(0, min(1, value.location.x / width))
        let time = CMTime(seconds: fraction * totalSeconds, preferredTimescale: 600)
        onScrub(time)
      }
  }

  func trackSidebar(label: String, icon: String) -> some View {
    VStack(spacing: 2) {
      Image(systemName: icon)
        .font(.system(size: 14))
      Text(label)
        .font(.system(size: 10))
    }
    .foregroundStyle(ReframedColors.primaryText)
  }

  private func screenTrackContent(width: CGFloat) -> some View {
    let h = trackHeight

    return ZStack(alignment: .leading) {
      videoTrackBackground(width: width, height: h, trimStart: videoTrimStart, trimEnd: videoTrimEnd)
    }
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay {
      trimBorderOverlay(
        width: width,
        height: h,
        trimStart: videoTrimStart,
        trimEnd: videoTrimEnd,
        borderColor: ReframedColors.screenTrackColor
      )
    }
    .contentShape(Rectangle())
    .coordinateSpace(name: "timeline")
    .overlay {
      trimHandleOverlay(
        width: width,
        height: h,
        trimStart: videoTrimStart,
        trimEnd: videoTrimEnd,
        onTrimStart: { f in
          editorState.updateTrimStart(CMTime(seconds: max(0, f) * totalSeconds, preferredTimescale: 600))
        },
        onTrimEnd: { f in
          editorState.updateTrimEnd(CMTime(seconds: min(1, f) * totalSeconds, preferredTimescale: 600))
        }
      )
    }
    .frame(width: width, height: h)
  }

  func videoTrackBackground(
    width: CGFloat,
    height: CGFloat,
    isWebcam: Bool = false,
    trimStart: Double,
    trimEnd: Double
  ) -> some View {
    let accentColor = isWebcam ? ReframedColors.webcamTrackColor : ReframedColors.screenTrackColor

    return ZStack(alignment: .leading) {
      Color.clear

      RoundedRectangle(cornerRadius: 10)
        .fill(accentColor.opacity(0.6))
        .frame(width: max(0, width * (trimEnd - trimStart)), height: height)
        .offset(x: width * trimStart)
    }
    .frame(width: width, height: height)
  }

  private func zoomTrackContent(width: CGFloat, keyframes: [ZoomKeyframe]) -> some View {
    ZoomKeyframeEditor(
      keyframes: keyframes,
      duration: totalSeconds,
      width: width,
      height: trackHeight,
      scrollOffset: scrollOffset,
      timelineZoom: timelineZoom,
      onAddKeyframe: { time in
        if let provider = editorState.cursorMetadataProvider {
          let pos = provider.sample(at: time)
          editorState.addManualZoomKeyframe(at: time, center: pos)
        }
      },
      onRemoveRegion: { startIndex, count in
        editorState.removeZoomRegion(startIndex: startIndex, count: count)
      },
      onUpdateRegion: { startIndex, count, newKeyframes in
        editorState.updateZoomRegion(startIndex: startIndex, count: count, newKeyframes: newKeyframes)
      }
    )
    .frame(width: width, height: trackHeight)
  }

  func trimBorderOverlay(
    width: CGFloat,
    height: CGFloat,
    trimStart: Double,
    trimEnd: Double,
    borderColor: Color
  ) -> some View {
    let startX = width * trimStart
    let endX = width * trimEnd
    let selectionWidth = endX - startX

    return ZStack(alignment: .leading) {
      Color.clear.frame(width: width, height: height)

      RoundedRectangle(cornerRadius: 10)
        .stroke(borderColor, lineWidth: 2)
        .frame(width: max(0, selectionWidth), height: height)
        .offset(x: startX)
    }
    .allowsHitTesting(false)
  }

  private func trimHandleOverlay(
    width: CGFloat,
    height: CGFloat,
    trimStart: Double,
    trimEnd: Double,
    onTrimStart: @escaping (Double) -> Void,
    onTrimEnd: @escaping (Double) -> Void
  ) -> some View {
    ZStack(alignment: .leading) {
      TrimHandle(
        edge: .leading,
        position: trimStart,
        totalWidth: width,
        height: height
      ) { newFraction in
        let clamped = min(newFraction, trimEnd - 0.01)
        onTrimStart(clamped)
      }

      TrimHandle(
        edge: .trailing,
        position: trimEnd,
        totalWidth: width,
        height: height
      ) { newFraction in
        let clamped = max(newFraction, trimStart + 0.01)
        onTrimEnd(clamped)
      }
    }
  }

  private func playheadOverlay(contentWidth: CGFloat, inset: CGFloat) -> some View {
    let frameWidth = contentWidth + inset * 2

    return SwiftUI.TimelineView(.animation(paused: !editorState.isPlaying)) { _ in
      let fraction: Double =
        if editorState.isPlaying {
          max(0, min(1, CMTimeGetSeconds(editorState.playerController.screenPlayer.currentTime()) / totalSeconds))
        } else {
          playheadFraction
        }
      let centerX = inset + contentWidth * fraction
      let lineHeight = timelineHeight - rulerHeight

      ZStack {
        Rectangle()
          .fill(ReframedColors.controlAccentColor.opacity(0.9))
          .frame(width: 2, height: lineHeight)
          .position(x: centerX, y: rulerHeight + lineHeight / 2)
          .allowsHitTesting(false)

        RoundedRectangle(cornerRadius: 6)
          .fill(ReframedColors.controlAccentColor.opacity(0.9))
          .frame(width: 12, height: 32)
          .position(x: centerX, y: rulerHeight / 2)
          .gesture(
            DragGesture(minimumDistance: 0)
              .onChanged { value in
                let fraction = max(0, min(1, (value.location.x - inset) / contentWidth))
                let time = CMTime(seconds: fraction * totalSeconds, preferredTimescale: 600)
                onScrub(time)
              }
          )
      }
      .frame(width: frameWidth, height: timelineHeight)
    }
  }
}

private struct CmdScrollZoomOverlay: NSViewRepresentable {
  let onZoom: (CGFloat, CGFloat) -> Void

  func makeNSView(context: Context) -> CmdScrollZoomNSView {
    CmdScrollZoomNSView(onZoom: onZoom)
  }

  func updateNSView(_ nsView: CmdScrollZoomNSView, context: Context) {
    nsView.onZoom = onZoom
  }

  class CmdScrollZoomNSView: NSView {
    var onZoom: (CGFloat, CGFloat) -> Void

    init(onZoom: @escaping (CGFloat, CGFloat) -> Void) {
      self.onZoom = onZoom
      super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
      guard NSEvent.modifierFlags.contains(.command) else { return nil }
      return super.hitTest(point)
    }

    override func scrollWheel(with event: NSEvent) {
      guard event.modifierFlags.contains(.command) else {
        super.scrollWheel(with: event)
        return
      }
      let cursorX = convert(event.locationInWindow, from: nil).x
      onZoom(event.scrollingDeltaY, cursorX)
    }
  }
}
