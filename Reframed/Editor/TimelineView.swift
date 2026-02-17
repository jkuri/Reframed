import AVFoundation
import SwiftUI

struct TimelineView: View {
  @Bindable var editorState: EditorState
  let systemAudioSamples: [Float]
  let micAudioSamples: [Float]
  var systemAudioProgress: Double?
  var micAudioProgress: Double?
  let onScrub: (CMTime) -> Void

  let sidebarWidth: CGFloat = 70
  private let rulerHeight: CGFloat = 32
  let trackHeight: CGFloat = 32

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

  var body: some View {
    ZStack(alignment: .top) {
      VStack(spacing: 8) {
        HStack(spacing: 0) {
          Color.clear
            .frame(width: sidebarWidth, height: rulerHeight)
          timeRuler
            .padding(.trailing, 8)
        }

        VStack(spacing: 10) {
          trackLane(
            label: "Screen",
            icon: "display",
            rowIndex: 0,
            borderColor: ReframedColors.screenTrackColor,
            content: { width, height in videoTrackBackground(width: width, height: height, trimStart: videoTrimStart, trimEnd: videoTrimEnd)
            },
            trimStart: videoTrimStart,
            trimEnd: videoTrimEnd,
            onTrimStart: { f in
              editorState.updateTrimStart(CMTime(seconds: max(0, f) * totalSeconds, preferredTimescale: 600))
            },
            onTrimEnd: { f in
              editorState.updateTrimEnd(CMTime(seconds: min(1, f) * totalSeconds, preferredTimescale: 600))
            }
          )

          if editorState.hasWebcam {
            cameraTrackLane()
          }

          if !systemAudioSamples.isEmpty {
            audioTrackLane(
              label: "System",
              icon: "speaker.wave.2",
              rowIndex: editorState.hasWebcam ? 2 : 1,
              trackType: .system,
              samples: systemAudioSamples,
              accentColor: ReframedColors.systemAudioColor
            )
          } else if editorState.hasSystemAudio {
            audioLoadingLane(
              label: "System",
              icon: "speaker.wave.2",
              progress: systemAudioProgress ?? 0,
              accentColor: ReframedColors.systemAudioColor
            )
          }

          if !micAudioSamples.isEmpty {
            audioTrackLane(
              label: "Mic",
              icon: "mic",
              rowIndex: {
                var idx = 1
                if editorState.hasWebcam { idx += 1 }
                if !systemAudioSamples.isEmpty { idx += 1 }
                return idx
              }(),
              trackType: .mic,
              samples: micAudioSamples,
              accentColor: ReframedColors.micAudioColor
            )
          } else if editorState.hasMicAudio {
            audioLoadingLane(
              label: "Mic",
              icon: "mic",
              progress: micAudioProgress ?? 0,
              accentColor: ReframedColors.micAudioColor
            )
          }

          if editorState.zoomEnabled {
            zoomTrackLane(keyframes: editorState.zoomTimeline?.allKeyframes ?? [])
          }
        }
      }

      playheadOverlay
    }
    .background(ReframedColors.panelBackground)
    .padding(.vertical, 8)
  }

  private var timeRuler: some View {
    GeometryReader { geo in
      let width = geo.size.width
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
      .frame(height: rulerHeight)
      .background(ReframedColors.panelBackground)
      .contentShape(Rectangle())
      .gesture(rulerScrubGesture(width: width))
    }
    .frame(height: rulerHeight)
  }

  private func rulerInterval(for duration: Double) -> Double {
    if duration <= 5 { return 1 }
    if duration <= 15 { return 2 }
    if duration <= 30 { return 5 }
    if duration <= 60 { return 10 }
    if duration <= 180 { return 30 }
    if duration <= 600 { return 60 }
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

  private func trackLane<Content: View>(
    label: String,
    icon: String,
    rowIndex: Int,
    borderColor: Color = ReframedColors.controlAccentColor,
    @ViewBuilder content: @escaping (CGFloat, CGFloat) -> Content,
    trimStart: Double,
    trimEnd: Double,
    onTrimStart: @escaping (Double) -> Void,
    onTrimEnd: @escaping (Double) -> Void
  ) -> some View {
    HStack(spacing: 0) {
      trackSidebar(label: label, icon: icon)
        .frame(width: sidebarWidth)

      GeometryReader { geo in
        let width = geo.size.width
        let h = geo.size.height

        ZStack(alignment: .leading) {
          content(width, h)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
          trimBorderOverlay(width: width, height: h, trimStart: trimStart, trimEnd: trimEnd, borderColor: borderColor)
        }
        .contentShape(Rectangle())
        .coordinateSpace(name: "timeline")
        .overlay {
          trimHandleOverlay(
            width: width,
            height: h,
            trimStart: trimStart,
            trimEnd: trimEnd,
            onTrimStart: onTrimStart,
            onTrimEnd: onTrimEnd
          )
        }
      }
      .padding(.trailing, 8)
    }
    .frame(height: trackHeight)
    .background(ReframedColors.panelBackground)
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

  private func videoTrackBackground(
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

  private func zoomTrackLane(keyframes: [ZoomKeyframe]) -> some View {
    HStack(spacing: 0) {
      trackSidebar(label: "Zoom", icon: "plus.magnifyingglass")
        .frame(width: sidebarWidth)

      GeometryReader { geo in
        ZoomKeyframeEditor(
          keyframes: keyframes,
          duration: totalSeconds,
          width: geo.size.width,
          height: geo.size.height,
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
      }
      .padding(.trailing, 8)
    }
    .frame(height: trackHeight)
    .background(ReframedColors.panelBackground)
  }

  private func trimBorderOverlay(width: CGFloat, height: CGFloat, trimStart: Double, trimEnd: Double, borderColor: Color) -> some View {
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

  private var playheadOverlay: some View {
    GeometryReader { geo in
      let contentWidth = geo.size.width - sidebarWidth - 8
      let centerX = sidebarWidth + contentWidth * playheadFraction

      Rectangle()
        .fill(ReframedColors.controlAccentColor.opacity(0.9))
        .frame(width: 2, height: geo.size.height - rulerHeight)
        .position(x: centerX, y: rulerHeight + (geo.size.height - rulerHeight) / 2)
        .allowsHitTesting(false)

      RoundedRectangle(cornerRadius: 6)
        .fill(ReframedColors.controlAccentColor.opacity(0.9))
        .frame(width: 12, height: 32)
        .position(x: centerX, y: rulerHeight / 2)
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { value in
              let x = value.location.x - sidebarWidth
              let fraction = max(0, min(1, x / contentWidth))
              let time = CMTime(seconds: fraction * totalSeconds, preferredTimescale: 600)
              onScrub(time)
            }
        )
    }
    .animation(editorState.isPlaying ? .linear(duration: 1.0 / 30.0) : .none, value: playheadFraction)
  }
}
