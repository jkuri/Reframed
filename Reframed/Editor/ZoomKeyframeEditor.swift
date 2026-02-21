import SwiftUI

struct ZoomKeyframeEditor: View {
  let keyframes: [ZoomKeyframe]
  let duration: Double
  let width: CGFloat
  let height: CGFloat
  let scrollOffset: CGFloat
  let timelineZoom: CGFloat
  let onAddKeyframe: (Double) -> Void
  let onRemoveRegion: (Int, Int) -> Void
  let onUpdateRegion: (Int, Int, [ZoomKeyframe]) -> Void
  @Environment(\.colorScheme) private var colorScheme

  @State private var dragOffset: CGFloat = 0
  @State private var dragType: RegionDragType?
  @State private var dragRegionStartIndex: Int?
  @State private var popoverRegionIndex: Int?

  private var regions: [ZoomRegion] {
    groupZoomRegions(from: keyframes)
  }

  var body: some View {
    let _ = colorScheme
    ZStack(alignment: .leading) {
      RoundedRectangle(cornerRadius: Track.borderRadius)
        .fill(ReframedColors.backgroundCard)
        .frame(width: width, height: height)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { location in
          let fraction = max(0, min(1, location.x / width))
          let time = fraction * duration
          let hitRegion = regions.first { region in
            let startX = (region.startTime / duration) * width
            let endX = (region.endTime / duration) * width
            return location.x >= startX && location.x <= endX
          }
          if hitRegion == nil {
            onAddKeyframe(time)
          }
        }

      if regions.isEmpty {
        let viewportWidth = width / timelineZoom
        let visibleCenterX = scrollOffset + viewportWidth / 2
        Text("Double-click to add zoom region")
          .font(.system(size: 11))
          .foregroundStyle(ReframedColors.secondaryText)
          .fixedSize()
          .position(x: visibleCenterX, y: height / 2)
          .allowsHitTesting(false)
      }

      ForEach(Array(regions.enumerated()), id: \.offset) { _, region in
        regionView(for: region)
      }
    }
    .frame(width: width, height: height)
    .clipShape(RoundedRectangle(cornerRadius: Track.borderRadius))
    .coordinateSpace(name: "zoomEditor")
  }

  private func effectiveTimes(
    for region: ZoomRegion
  ) -> (start: Double, zoomStart: Double, zoomEnd: Double, end: Double) {
    guard dragRegionStartIndex == region.startIndex, let dt = dragType else {
      return (region.startTime, region.zoomStartTime, region.zoomEndTime, region.endTime)
    }
    let timeDelta = (dragOffset / width) * duration

    let otherRegions = regions.filter { $0.startIndex != region.startIndex }
    let prevEnd: Double = otherRegions.last(where: { $0.endTime <= region.startTime })?.endTime ?? 0
    let nextStart: Double = otherRegions.first(where: { $0.startTime >= region.endTime })?.startTime ?? duration

    switch dt {
    case .move:
      let regionDur = region.endTime - region.startTime
      let clampedStart = max(prevEnd, min(nextStart - regionDur, region.startTime + timeDelta))
      let shift = clampedStart - region.startTime
      return (
        clampedStart,
        region.zoomStartTime + shift,
        region.zoomEndTime + shift,
        clampedStart + regionDur
      )
    case .resizeLeft:
      let origEaseIn = region.zoomStartTime - region.startTime
      let newStart = max(prevEnd, min(region.endTime - 0.05, region.startTime + timeDelta))
      var newHoldStart = newStart + origEaseIn
      newHoldStart = min(newHoldStart, region.zoomEndTime - 0.01)
      let clampedStart = min(newStart, newHoldStart)
      return (
        clampedStart,
        newHoldStart,
        region.zoomEndTime,
        region.endTime
      )
    case .resizeRight:
      let origEaseOut = region.endTime - region.zoomEndTime
      let newEnd = max(region.startTime + 0.05, min(nextStart, region.endTime + timeDelta))
      var newHoldEnd = newEnd - origEaseOut
      newHoldEnd = max(newHoldEnd, region.zoomStartTime + 0.01)
      let clampedEnd = max(newEnd, newHoldEnd)
      return (
        region.startTime,
        region.zoomStartTime,
        newHoldEnd,
        clampedEnd
      )
    }
  }

  private func commitDrag(for region: ZoomRegion) {
    guard let dt = dragType else { return }
    let timeDelta = (dragOffset / width) * duration
    var regionKfs = Array(keyframes[region.startIndex..<(region.startIndex + region.count)])

    var proposedStart: Double
    var proposedEnd: Double

    switch dt {
    case .move:
      for i in 0..<regionKfs.count {
        regionKfs[i].t = max(0, min(duration, regionKfs[i].t + timeDelta))
      }
      proposedStart = max(0, region.startTime + timeDelta)
      proposedEnd = min(duration, region.endTime + timeDelta)
    case .resizeLeft:
      let origEaseIn = region.zoomStartTime - region.startTime
      let newStart = max(0, region.startTime + timeDelta)
      var newHoldStart = newStart + origEaseIn
      newHoldStart = min(newHoldStart, region.zoomEndTime - 0.01)
      let clampedStart = min(newStart, newHoldStart)
      if region.endTime - clampedStart < 0.05 { return }
      let firstZoomIdx = regionKfs.firstIndex(where: { $0.zoomLevel > 1.0 })
      for i in 0..<regionKfs.count {
        if regionKfs[i].zoomLevel <= 1.0 && i == 0 {
          regionKfs[i].t = clampedStart
        } else if i == firstZoomIdx {
          regionKfs[i].t = newHoldStart
        }
      }
      proposedStart = clampedStart
      proposedEnd = region.endTime
    case .resizeRight:
      let origEaseOut = region.endTime - region.zoomEndTime
      let newEnd = min(duration, region.endTime + timeDelta)
      var newHoldEnd = newEnd - origEaseOut
      newHoldEnd = max(newHoldEnd, region.zoomStartTime + 0.01)
      let clampedEnd = max(newEnd, newHoldEnd)
      if clampedEnd - region.startTime < 0.05 { return }
      let lastZoomIdx = regionKfs.lastIndex(where: { $0.zoomLevel > 1.0 })
      for i in 0..<regionKfs.count {
        if regionKfs[i].zoomLevel <= 1.0 && i == regionKfs.count - 1 {
          regionKfs[i].t = clampedEnd
        } else if i == lastZoomIdx {
          regionKfs[i].t = newHoldEnd
        }
      }
      proposedStart = region.startTime
      proposedEnd = clampedEnd
    }

    let otherRegions = regions.filter { $0.startIndex != region.startIndex }
    let overlaps = otherRegions.contains { other in
      proposedStart < other.endTime && proposedEnd > other.startTime
    }
    if overlaps { return }

    onUpdateRegion(region.startIndex, region.count, regionKfs)
  }

  @ViewBuilder
  private func regionView(for region: ZoomRegion) -> some View {
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
          Text(String(format: "%.1fs", totalDur))
            .font(.system(size: Track.fontSize))
            .lineLimit(1)
        }
        if regionWidth > 160, easeIn > 0.01 || easeOut > 0.01 {
          Text(String(format: "↗%.1fs ↘%.1fs", easeIn, easeOut))
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
