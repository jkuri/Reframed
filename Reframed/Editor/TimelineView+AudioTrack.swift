import SwiftUI

extension TimelineView {
  func audioTrackContent(
    trackType: AudioTrackType,
    samples: [Float],
    accentColor: Color,
    width: CGFloat
  ) -> some View {
    let h = trackHeight
    let regions = trackType == .system ? editorState.systemAudioRegions : editorState.micAudioRegions

    return ZStack(alignment: .leading) {
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
    .clipped()
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

  func audioLoadingContent(
    progress: Double,
    message: String? = nil,
    accentColor: Color,
    width: CGFloat
  ) -> some View {
    let h = trackHeight

    return ZStack {
      RoundedRectangle(cornerRadius: 10)
        .fill(accentColor.opacity(0.06))

      HStack(spacing: 10) {
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 2.5)
            .fill(accentColor.opacity(0.15))
            .frame(width: 100, height: 5)
          RoundedRectangle(cornerRadius: 2.5)
            .fill(accentColor.opacity(0.6))
            .frame(width: 100 * max(0, min(1, progress)), height: 5)
        }
        .fixedSize()

        Text(message ?? "Generating waveform… \(Int(progress * 100))%")
          .font(.system(size: 10).monospacedDigit())
          .foregroundStyle(ReframedColors.dimLabel)
          .frame(width: 160, alignment: .leading)
      }
      .fixedSize()
    }
    .frame(width: width, height: h)
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  func audioRegionCanvas(
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
  func audioRegionView(
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
        fullHeight: height,
        accentColor: accentColor
      )
      .clipShape(RoundedRectangle(cornerRadius: 6))

      RoundedRectangle(cornerRadius: 6)
        .strokeBorder(accentColor, lineWidth: 2)
    }
    .frame(width: regionWidth, height: height)
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

  func audioRegionWaveform(
    samples: [Float],
    startX: CGFloat,
    endX: CGFloat,
    fullWidth: CGFloat,
    fullHeight: CGFloat,
    accentColor: Color
  ) -> some View {
    Canvas { context, size in
      let count = samples.count
      guard count > 1 else { return }
      let midY = fullHeight / 2
      let maxAmp = fullHeight * 0.4
      let step = fullWidth / CGFloat(count - 1)

      var topPoints: [CGPoint] = []
      var bottomPoints: [CGPoint] = []
      for i in 0..<count {
        let x = CGFloat(i) * step
        let amp = CGFloat(samples[i]) * maxAmp
        topPoints.append(CGPoint(x: x, y: midY - amp))
        bottomPoints.append(CGPoint(x: x, y: midY + amp))
      }

      let yOffset = (fullHeight - size.height) / 2
      context.translateBy(x: -startX, y: -yOffset)
      let activePath = buildWaveformPath(top: topPoints, bottom: bottomPoints, minX: startX, maxX: endX)
      context.fill(activePath, with: .color(accentColor))
    }
    .allowsHitTesting(false)
  }

  func effectiveAudioRegion(_ region: AudioRegionData, width: CGFloat) -> (start: Double, end: Double) {
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

  func commitAudioDrag(region: AudioRegionData, trackType: AudioTrackType, width: CGFloat) {
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
}
