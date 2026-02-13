import AVFoundation
import AppKit
import SwiftUI

struct TimelineView: View {
  @Bindable var editorState: EditorState
  let thumbnails: [NSImage]
  let systemAudioSamples: [Float]
  let micAudioSamples: [Float]
  let onScrub: (CMTime) -> Void

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

  private var sysAudioTrimStart: Double {
    CMTimeGetSeconds(editorState.systemAudioTrimStart) / totalSeconds
  }

  private var sysAudioTrimEnd: Double {
    CMTimeGetSeconds(editorState.systemAudioTrimEnd) / totalSeconds
  }

  private var micAudioTrimStart: Double {
    CMTimeGetSeconds(editorState.micAudioTrimStart) / totalSeconds
  }

  private var micAudioTrimEnd: Double {
    CMTimeGetSeconds(editorState.micAudioTrimEnd) / totalSeconds
  }

  var body: some View {
    VStack(spacing: 16) {
      trackView(
        height: 70,
        content: { width, height in thumbnailStrip(width: width, height: height) },
        trimStart: videoTrimStart,
        trimEnd: videoTrimEnd,
        onTrimStart: { f in
          editorState.updateTrimStart(CMTime(seconds: max(0, f) * totalSeconds, preferredTimescale: 600))
        },
        onTrimEnd: { f in
          editorState.updateTrimEnd(CMTime(seconds: min(1, f) * totalSeconds, preferredTimescale: 600))
        }
      )

      if !systemAudioSamples.isEmpty {
        trackView(
          height: 70,
          content: { width, height in
            ZStack {
              RoundedRectangle(cornerRadius: 8).fill(ReframedColors.fieldBackground)
              waveformView(samples: systemAudioSamples, trimStart: sysAudioTrimStart, trimEnd: sysAudioTrimEnd, width: width, height: height)
            }
          },
          trimStart: sysAudioTrimStart,
          trimEnd: sysAudioTrimEnd,
          onTrimStart: { f in
            editorState.updateSystemAudioTrimStart(CMTime(seconds: max(0, f) * totalSeconds, preferredTimescale: 600))
          },
          onTrimEnd: { f in
            editorState.updateSystemAudioTrimEnd(CMTime(seconds: min(1, f) * totalSeconds, preferredTimescale: 600))
          }
        )
      }

      if !micAudioSamples.isEmpty {
        trackView(
          height: 70,
          content: { width, height in
            ZStack {
              RoundedRectangle(cornerRadius: 8).fill(ReframedColors.fieldBackground)
              waveformView(samples: micAudioSamples, trimStart: micAudioTrimStart, trimEnd: micAudioTrimEnd, width: width, height: height)
            }
          },
          trimStart: micAudioTrimStart,
          trimEnd: micAudioTrimEnd,
          onTrimStart: { f in
            editorState.updateMicAudioTrimStart(CMTime(seconds: max(0, f) * totalSeconds, preferredTimescale: 600))
          },
          onTrimEnd: { f in
            editorState.updateMicAudioTrimEnd(CMTime(seconds: min(1, f) * totalSeconds, preferredTimescale: 600))
          }
        )
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(ReframedColors.panelBackground)
  }

  private func trackView<Content: View>(
    height: CGFloat,
    @ViewBuilder content: @escaping (CGFloat, CGFloat) -> Content,
    trimStart: Double,
    trimEnd: Double,
    onTrimStart: @escaping (Double) -> Void,
    onTrimEnd: @escaping (Double) -> Void
  ) -> some View {
    GeometryReader { geo in
      let width = geo.size.width
      let h = geo.size.height

      ZStack(alignment: .leading) {
        content(width, h)
        dimmedRegions(width: width, height: h, trimStart: trimStart, trimEnd: trimEnd)
        playheadLine(width: width, height: h)
      }
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(ReframedColors.subtleBorder, lineWidth: 1)
      )
      .overlay {
        trimBorderOverlay(width: width, height: h, trimStart: trimStart, trimEnd: trimEnd)
      }
      .contentShape(Rectangle())
      .coordinateSpace(name: "timeline")
      .gesture(scrubGesture(width: width))
      .overlay {
        trimHandleOverlay(width: width, height: h, trimStart: trimStart, trimEnd: trimEnd, onTrimStart: onTrimStart, onTrimEnd: onTrimEnd)
      }
    }
    .frame(height: height)
  }

  private func dimmedRegions(width: CGFloat, height: CGFloat, trimStart: Double, trimEnd: Double) -> some View {
    ZStack(alignment: .leading) {
      Color.clear.frame(width: width, height: height)

      Rectangle()
        .fill(ReframedColors.panelBackground.opacity(0.7))
        .frame(width: max(0, width * trimStart), height: height)

      Rectangle()
        .fill(ReframedColors.panelBackground.opacity(0.7))
        .frame(width: max(0, width * (1 - trimEnd)), height: height)
        .offset(x: width * trimEnd)
    }
    .allowsHitTesting(false)
  }

  private func trimBorderOverlay(width: CGFloat, height: CGFloat, trimStart: Double, trimEnd: Double) -> some View {
    let startX = width * trimStart
    let endX = width * trimEnd
    let selectionWidth = endX - startX
    let hw = TrimHandle.handleWidth
    let borderWidth: CGFloat = 2

    return ZStack(alignment: .leading) {
      Color.clear.frame(width: width, height: height)

      ZStack {
        UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 8, bottomTrailingRadius: 0, topTrailingRadius: 0)
          .fill(Color.accentColor)
        RoundedRectangle(cornerRadius: 1)
          .fill(.white.opacity(0.9))
          .frame(width: 2, height: 14)
      }
      .frame(width: hw, height: height)
      .offset(x: startX - hw)

      ZStack {
        UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 8, topTrailingRadius: 8)
          .fill(Color.accentColor)
        RoundedRectangle(cornerRadius: 1)
          .fill(.white.opacity(0.9))
          .frame(width: 2, height: 14)
      }
      .frame(width: hw, height: height)
      .offset(x: endX)

      Rectangle()
        .fill(Color.accentColor)
        .frame(width: max(0, selectionWidth), height: borderWidth)
        .offset(x: startX, y: -height / 2 + borderWidth / 2)

      Rectangle()
        .fill(Color.accentColor)
        .frame(width: max(0, selectionWidth), height: borderWidth)
        .offset(x: startX, y: height / 2 - borderWidth / 2)
    }
    .allowsHitTesting(false)
  }

  private func trimHandleOverlay(
    width: CGFloat, height: CGFloat,
    trimStart: Double, trimEnd: Double,
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

  private func playheadLine(width: CGFloat, height: CGFloat) -> some View {
    Rectangle()
      .fill(.red)
      .frame(width: 2, height: height + 8)
      .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0)
      .offset(x: width * playheadFraction - 1)
      .allowsHitTesting(false)
  }

  private func waveformView(samples: [Float], trimStart: Double, trimEnd: Double, width: CGFloat, height: CGFloat) -> some View {
    Canvas { context, size in
      let count = samples.count
      guard count > 0 else { return }
      let midY = size.height / 2
      let maxAmp = size.height * 0.45
      let step = size.width / CGFloat(count - 1)
      let trimStartX = size.width * trimStart
      let trimEndX = size.width * trimEnd

      var topPoints: [CGPoint] = []
      var bottomPoints: [CGPoint] = []
      for i in 0..<count {
        let x = CGFloat(i) * step
        let amp = CGFloat(samples[i]) * maxAmp
        topPoints.append(CGPoint(x: x, y: midY - amp))
        bottomPoints.append(CGPoint(x: x, y: midY + amp))
      }

      let activeShape = buildWaveformPath(top: topPoints, bottom: bottomPoints, minX: trimStartX, maxX: trimEndX)
      let inactiveLeftShape = buildWaveformPath(top: topPoints, bottom: bottomPoints, minX: 0, maxX: trimStartX)
      let inactiveRightShape = buildWaveformPath(top: topPoints, bottom: bottomPoints, minX: trimEndX, maxX: size.width)

      context.fill(activeShape, with: .color(ReframedColors.tertiaryText))
      context.fill(inactiveLeftShape, with: .color(ReframedColors.tertiaryText.opacity(0.4)))
      context.fill(inactiveRightShape, with: .color(ReframedColors.tertiaryText.opacity(0.4)))
    }
    .allowsHitTesting(false)
  }

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

  private func scrubGesture(width: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        let fraction = max(0, min(1, value.location.x / width))
        let time = CMTime(seconds: fraction * totalSeconds, preferredTimescale: 600)
        onScrub(time)
      }
  }

  @ViewBuilder
  private func thumbnailStrip(width: CGFloat, height: CGFloat) -> some View {
    if thumbnails.isEmpty {
      Rectangle()
        .fill(ReframedColors.fieldBackground)
        .frame(width: width, height: height)
    } else {
      HStack(spacing: 0) {
        ForEach(Array(thumbnails.enumerated()), id: \.offset) { _, image in
          Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: width / CGFloat(thumbnails.count), height: height)
            .clipped()
        }
      }
    }
  }
}
