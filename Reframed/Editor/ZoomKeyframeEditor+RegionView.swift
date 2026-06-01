import SwiftUI

extension ZoomKeyframeEditor {
  @ViewBuilder
  func regionView(for region: ZoomRegion) -> some View {
    let times = effectiveTimes(for: region)
    let startX = max(0, (times.start / duration) * width)
    let endX = min(width, (times.end / duration) * width)
    let regionWidth = max(4, endX - startX)
    let totalDur = times.end - times.start
    let easeIn = times.zoomStart - times.start
    let easeOut = times.end - times.zoomEnd

    let edgeThreshold = min(8.0, regionWidth * 0.2)

    ZStack {
      RoundedRectangle(cornerRadius: Track.borderRadius)
        .fill(Track.background)

      HStack(spacing: 3) {
        Image(systemName: region.isAuto ? "sparkle.magnifyingglass" : "plus.magnifyingglass")
          .font(.system(size: Track.fontSize))
        if regionWidth > 50 {
          Text(String(format: "%.1fx", region.peakZoom))
            .font(.system(size: Track.fontSize, weight: Track.fontWeight))
            .lineLimit(1)
        }
        if regionWidth > 90 {
          Text(String(format: "%.1f秒", totalDur))
            .font(.system(size: Track.fontSize))
            .lineLimit(1)
        }
        if regionWidth > 160, easeIn > 0.01 || easeOut > 0.01 {
          Text(String(format: "↗%.1f秒 ↘%.1f秒", easeIn, easeOut))
            .font(.system(size: Track.fontSize - 1))
            .lineLimit(1)
        }
      }
      .foregroundStyle(Track.regionTextColor)

      RoundedRectangle(cornerRadius: Track.borderRadius)
        .strokeBorder(Track.borderColor, lineWidth: Track.borderWidth)
    }
    .frame(width: regionWidth, height: height)
    .contentShape(Rectangle())
    .overlay {
      if !region.isAuto {
        RightClickOverlay {
          popoverRegionIndex = region.startIndex
        }
      }
    }
    .gesture(
      DragGesture(minimumDistance: 3, coordinateSpace: .named("zoomEditor"))
        .onChanged { value in
          guard !region.isAuto else { return }
          popoverRegionIndex = nil
          if dragType == nil {
            let origStartX = (region.startTime / duration) * width
            let origEndX = (region.endTime / duration) * width
            let origWidth = origEndX - origStartX
            let relX = value.startLocation.x - origStartX
            let effectiveEdge = min(8.0, origWidth * 0.2)
            if relX <= effectiveEdge {
              dragType = .resizeLeft
            } else if relX >= origWidth - effectiveEdge {
              dragType = .resizeRight
            } else {
              dragType = .move
            }
            dragRegionStartIndex = region.startIndex
          }
          dragOffset = value.translation.width
        }
        .onEnded { _ in
          guard dragType != nil else { return }
          commitDrag(for: region)
          dragOffset = 0
          dragType = nil
          dragRegionStartIndex = nil
        }
    )
    .popover(
      isPresented: Binding(
        get: { popoverRegionIndex == region.startIndex },
        set: { if !$0 { popoverRegionIndex = nil } }
      )
    ) {
      RegionEditPopover(
        region: region,
        originalKeyframes: Array(keyframes[region.startIndex..<(region.startIndex + region.count)]),
        duration: duration,
        onUpdate: onUpdateRegion,
        onRemove: {
          popoverRegionIndex = nil
          onRemoveRegion(region.startIndex, region.count)
        }
      )
      .presentationBackground(ReframedColors.backgroundPopover)
    }
    .onContinuousHover { phase in
      guard !region.isAuto else { return }
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
}
