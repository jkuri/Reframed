import AVFoundation
import SwiftUI

struct TimelineView: View {
  @Bindable var editorState: EditorState
  let systemAudioSamples: [Float]
  let micAudioSamples: [Float]
  let onScrub: (CMTime) -> Void

  private let sidebarWidth: CGFloat = 70
  private let rulerHeight: CGFloat = 28
  private let trackHeight: CGFloat = 42

  private var totalSeconds: Double {
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

  @State private var audioDragOffset: CGFloat = 0
  @State private var audioDragType: RegionDragType?
  @State private var audioDragRegionId: UUID?

  var body: some View {
    ZStack(alignment: .top) {
      VStack(spacing: 0) {
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
            trackLane(
              label: "Camera",
              icon: "web.camera",
              rowIndex: 1,
              borderColor: ReframedColors.webcamTrackColor,
              content: { width, height in
                videoTrackBackground(width: width, height: height, isWebcam: true, trimStart: videoTrimStart, trimEnd: videoTrimEnd)
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

  // MARK: - Time Ruler

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
            context.stroke(tickPath, with: .color(ReframedColors.tertiaryText), lineWidth: 1)

            let label = formatRulerTime(t)
            let text = Text(label)
              .font(.system(size: 9, design: .monospaced))
              .foregroundStyle(ReframedColors.secondaryText)
            context.draw(context.resolve(text), at: CGPoint(x: x, y: size.height - 16), anchor: .bottom)
          } else {
            let tickPath = Path { p in
              p.move(to: CGPoint(x: x, y: size.height - 5))
              p.addLine(to: CGPoint(x: x, y: size.height))
            }
            context.stroke(tickPath, with: .color(ReframedColors.tertiaryText.opacity(0.5)), lineWidth: 0.5)
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

  // MARK: - Track Lane

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

  private func trackSidebar(label: String, icon: String) -> some View {
    VStack(spacing: 2) {
      Image(systemName: icon)
        .font(.system(size: 12))
      Text(label)
        .font(.system(size: 9))
    }
    .foregroundStyle(ReframedColors.secondaryText)
  }

  // MARK: - Video Content

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
        .fill(accentColor.opacity(0.1))
        .frame(width: max(0, width * (trimEnd - trimStart)), height: height)
        .offset(x: width * trimStart)
    }
    .frame(width: width, height: height)
  }

  // MARK: - Audio Track (Multi-Region)

  private func audioTrackLane(
    label: String,
    icon: String,
    rowIndex: Int,
    trackType: AudioTrackType,
    samples: [Float],
    accentColor: Color
  ) -> some View {
    HStack(spacing: 0) {
      trackSidebar(label: label, icon: icon)
        .frame(width: sidebarWidth)

      GeometryReader { geo in
        let width = geo.size.width
        let h = geo.size.height
        let regions = trackType == .system ? editorState.systemAudioRegions : editorState.micAudioRegions

        ZStack(alignment: .leading) {
          audioRegionCanvas(
            samples: samples,
            width: width,
            height: h
          )

          ForEach(regions) { region in
            audioRegionView(
              region: region,
              trackType: trackType,
              samples: samples,
              width: width,
              height: h,
              accentColor: accentColor
            )
          }

          if regions.isEmpty {
            Text("Double-click to add audio region")
              .font(.system(size: 11))
              .foregroundStyle(ReframedColors.dimLabel)
              .frame(width: width, height: h)
              .allowsHitTesting(false)
          }
        }
        .frame(width: width, height: h)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .coordinateSpace(name: trackType)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { location in
          let time = (location.x / width) * totalSeconds
          let hitRegion = regions.first { r in
            let eff = effectiveAudioRegion(r, width: width)
            let startX = (eff.start / totalSeconds) * width
            let endX = (eff.end / totalSeconds) * width
            return location.x >= startX && location.x <= endX
          }
          if hitRegion == nil {
            editorState.addRegion(trackType: trackType, atTime: time)
          }
        }
      }
      .padding(.trailing, 8)
    }
    .frame(height: trackHeight)
    .background(ReframedColors.panelBackground)
  }

  private func audioRegionCanvas(
    samples: [Float],
    width: CGFloat,
    height: CGFloat
  ) -> some View {
    Canvas { context, size in
      let count = samples.count
      guard count > 1 else { return }
      let midY = size.height / 2
      let maxAmp = size.height * 0.4
      let step = size.width / CGFloat(count - 1)

      var topPoints: [CGPoint] = []
      var bottomPoints: [CGPoint] = []
      for i in 0..<count {
        let x = CGFloat(i) * step
        let amp = CGFloat(samples[i]) * maxAmp
        topPoints.append(CGPoint(x: x, y: midY - amp))
        bottomPoints.append(CGPoint(x: x, y: midY + amp))
      }

      let fullPath = buildWaveformPath(top: topPoints, bottom: bottomPoints, minX: 0, maxX: size.width)
      context.fill(fullPath, with: .color(ReframedColors.tertiaryText.opacity(0.4)))
    }
    .frame(width: width, height: height)
    .allowsHitTesting(false)
  }

  @ViewBuilder
  private func audioRegionView(
    region: AudioRegionData,
    trackType: AudioTrackType,
    samples: [Float],
    width: CGFloat,
    height: CGFloat,
    accentColor: Color
  ) -> some View {
    let effective = effectiveAudioRegion(region, width: width)
    let startX = max(0, CGFloat(effective.start / totalSeconds) * width)
    let endX = min(width, CGFloat(effective.end / totalSeconds) * width)
    let regionWidth = max(4, endX - startX)
    let edgeThreshold: CGFloat = 8

    ZStack {
      RoundedRectangle(cornerRadius: 6)
        .fill(accentColor.opacity(0.15))

      audioRegionWaveform(
        samples: samples,
        startX: startX,
        endX: endX,
        fullWidth: width,
        accentColor: accentColor
      )
      .clipShape(RoundedRectangle(cornerRadius: 6))

      RoundedRectangle(cornerRadius: 6)
        .stroke(accentColor, lineWidth: 2)
    }
    .frame(width: regionWidth, height: height - 6)
    .contentShape(Rectangle())
    .overlay {
      RightClickOverlay {
        editorState.removeRegion(trackType: trackType, regionId: region.id)
      }
    }
    .gesture(
      DragGesture(minimumDistance: 3, coordinateSpace: .named(trackType))
        .onChanged { value in
          if audioDragType == nil {
            let origStartX = CGFloat(region.startSeconds / totalSeconds) * width
            let origEndX = CGFloat(region.endSeconds / totalSeconds) * width
            let origWidth = origEndX - origStartX
            let relX = value.startLocation.x - origStartX
            if relX <= edgeThreshold && origWidth > edgeThreshold * 3 {
              audioDragType = .resizeLeft
            } else if relX >= origWidth - edgeThreshold && origWidth > edgeThreshold * 3 {
              audioDragType = .resizeRight
            } else {
              audioDragType = .move
            }
            audioDragRegionId = region.id
          }
          audioDragOffset = value.translation.width
        }
        .onEnded { _ in
          guard audioDragType != nil else { return }
          commitAudioDrag(region: region, trackType: trackType, width: width)
          audioDragOffset = 0
          audioDragType = nil
          audioDragRegionId = nil
        }
    )
    .onContinuousHover { phase in
      switch phase {
      case .active(let location):
        if location.x <= edgeThreshold || location.x >= regionWidth - edgeThreshold {
          NSCursor.resizeLeftRight.set()
        } else {
          NSCursor.openHand.set()
        }
      case .ended:
        NSCursor.arrow.set()
      @unknown default:
        break
      }
    }
    .position(x: startX + regionWidth / 2, y: height / 2)
  }

  private func audioRegionWaveform(
    samples: [Float],
    startX: CGFloat,
    endX: CGFloat,
    fullWidth: CGFloat,
    accentColor: Color
  ) -> some View {
    Canvas { context, size in
      let count = samples.count
      guard count > 1 else { return }
      let midY = size.height / 2
      let maxAmp = size.height * 0.4
      let step = fullWidth / CGFloat(count - 1)

      var topPoints: [CGPoint] = []
      var bottomPoints: [CGPoint] = []
      for i in 0..<count {
        let x = CGFloat(i) * step
        let amp = CGFloat(samples[i]) * maxAmp
        topPoints.append(CGPoint(x: x, y: midY - amp))
        bottomPoints.append(CGPoint(x: x, y: midY + amp))
      }

      context.translateBy(x: -startX, y: 0)
      let activePath = buildWaveformPath(top: topPoints, bottom: bottomPoints, minX: startX, maxX: endX)
      context.fill(activePath, with: .color(accentColor))
    }
    .allowsHitTesting(false)
  }

  private func effectiveAudioRegion(_ region: AudioRegionData, width: CGFloat) -> (start: Double, end: Double) {
    guard audioDragRegionId == region.id, let dt = audioDragType else {
      return (region.startSeconds, region.endSeconds)
    }
    let timeDelta = (audioDragOffset / width) * totalSeconds

    switch dt {
    case .move:
      return (region.startSeconds + timeDelta, region.endSeconds + timeDelta)
    case .resizeLeft:
      return (region.startSeconds + timeDelta, region.endSeconds)
    case .resizeRight:
      return (region.startSeconds, region.endSeconds + timeDelta)
    }
  }

  private func commitAudioDrag(region: AudioRegionData, trackType: AudioTrackType, width: CGFloat) {
    let timeDelta = (audioDragOffset / width) * totalSeconds

    switch audioDragType {
    case .move:
      editorState.moveRegion(trackType: trackType, regionId: region.id, newStart: region.startSeconds + timeDelta)
    case .resizeLeft:
      editorState.updateRegionStart(trackType: trackType, regionId: region.id, newStart: region.startSeconds + timeDelta)
    case .resizeRight:
      editorState.updateRegionEnd(trackType: trackType, regionId: region.id, newEnd: region.endSeconds + timeDelta)
    case nil:
      break
    }
  }

  // MARK: - Waveform

  private func buildWaveformPath(top: [CGPoint], bottom: [CGPoint], minX: CGFloat, maxX: CGFloat) -> Path {
    guard top.count > 1, maxX > minX else { return Path() }
    let step = top.count > 1 ? top[1].x - top[0].x : 1

    var clippedTop: [CGPoint] = []
    var clippedBottom: [CGPoint] = []

    for i in 0..<top.count {
      let x = top[i].x
      if x >= minX - step && x <= maxX + step {
        let cx = max(minX, min(maxX, x))
        if x != cx {
          let t: CGFloat
          if i > 0 && x < minX {
            t = (minX - top[i].x) / step
            let ty = top[i].y + (top[min(i + 1, top.count - 1)].y - top[i].y) * t
            let by = bottom[i].y + (bottom[min(i + 1, bottom.count - 1)].y - bottom[i].y) * t
            clippedTop.append(CGPoint(x: minX, y: ty))
            clippedBottom.append(CGPoint(x: minX, y: by))
          } else if x > maxX {
            t = (maxX - top[max(i - 1, 0)].x) / step
            let ty = top[max(i - 1, 0)].y + (top[i].y - top[max(i - 1, 0)].y) * t
            let by = bottom[max(i - 1, 0)].y + (bottom[i].y - bottom[max(i - 1, 0)].y) * t
            clippedTop.append(CGPoint(x: maxX, y: ty))
            clippedBottom.append(CGPoint(x: maxX, y: by))
          }
        } else {
          clippedTop.append(top[i])
          clippedBottom.append(bottom[i])
        }
      }
    }

    guard clippedTop.count > 1 else { return Path() }

    var path = Path()
    path.move(to: clippedTop[0])
    for i in 1..<clippedTop.count {
      let prev = clippedTop[i - 1]
      let curr = clippedTop[i]
      let mx = (prev.x + curr.x) / 2
      path.addCurve(to: curr, control1: CGPoint(x: mx, y: prev.y), control2: CGPoint(x: mx, y: curr.y))
    }
    for i in stride(from: clippedBottom.count - 1, through: 0, by: -1) {
      let curr = clippedBottom[i]
      if i == clippedBottom.count - 1 {
        path.addLine(to: curr)
      } else {
        let prev = clippedBottom[i + 1]
        let mx = (prev.x + curr.x) / 2
        path.addCurve(to: curr, control1: CGPoint(x: mx, y: prev.y), control2: CGPoint(x: mx, y: curr.y))
      }
    }
    path.closeSubpath()
    return path
  }

  // MARK: - Zoom Track

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

  // MARK: - Trim & Playhead

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

  // MARK: - Playhead Overlay

  private var playheadOverlay: some View {
    GeometryReader { geo in
      let contentWidth = geo.size.width - sidebarWidth - 8
      let centerX = sidebarWidth + contentWidth * playheadFraction

      Rectangle()
        .fill(ReframedColors.controlAccentColor.opacity(0.5))
        .frame(width: 2, height: geo.size.height - rulerHeight)
        .position(x: centerX, y: rulerHeight + (geo.size.height - rulerHeight) / 2)
        .allowsHitTesting(false)

      RoundedRectangle(cornerRadius: 6)
        .fill(ReframedColors.controlAccentColor.opacity(0.9))
        .frame(width: 12, height: 28)
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
  }
}
