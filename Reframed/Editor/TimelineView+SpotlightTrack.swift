import SwiftUI

extension TimelineView {
  func spotlightTrackContent(width: CGFloat) -> some View {
    let h = trackHeight
    let regions = editorState.spotlightRegions

    return ZStack(alignment: .leading) {
      ForEach(regions) { region in
        spotlightRegionView(
          region: region,
          width: width,
          height: h
        )
      }

      if regions.isEmpty {
        let viewportWidth = width / timelineZoom
        let visibleCenterX = scrollOffset + viewportWidth / 2
        Text("Double-click to add spotlight region")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.secondaryText)
          .fixedSize()
          .position(x: visibleCenterX, y: h / 2)
          .allowsHitTesting(false)
      }
    }
    .frame(width: width, height: h)
    .clipped()
    .coordinateSpace(name: "spotlightRegion")
    .contentShape(Rectangle())
    .onTapGesture(count: 2) { location in
      let time = (location.x / width) * totalSeconds
      let hitRegion = regions.first { r in
        let eff = effectiveSpotlightRegion(r, width: width)
        let startX = (eff.start / totalSeconds) * width
        let endX = (eff.end / totalSeconds) * width
        return location.x >= startX && location.x <= endX
      }
      if hitRegion == nil {
        editorState.addSpotlightRegion(atTime: time)
      }
    }
  }

  @ViewBuilder
  func spotlightRegionView(
    region: SpotlightRegionData,
    width: CGFloat,
    height: CGFloat
  ) -> some View {
    let effective = effectiveSpotlightRegion(region, width: width)
    let startX = max(0, CGFloat(effective.start / totalSeconds) * width)
    let endX = min(width, CGFloat(effective.end / totalSeconds) * width)
    let regionWidth = max(4, endX - startX)
    let edgeThreshold = min(8.0, regionWidth * 0.2)
    let isPopoverShown = popoverSpotlightRegionId == region.id
    let hasOverrides =
      region.customRadius != nil || region.customDimOpacity != nil || region.customEdgeSoftness != nil

    ZStack {
      RoundedRectangle(cornerRadius: Track.borderRadius)
        .fill(Track.background)

      HStack(spacing: 3) {
        Image(systemName: "light.max")
          .font(.system(size: Track.fontSize))
        if regionWidth > 50 {
          Text("Spotlight")
            .font(.system(size: Track.fontSize, weight: Track.fontWeight))
            .lineLimit(1)
        }
        if hasOverrides && regionWidth > 30 {
          Image(systemName: "slider.horizontal.3")
            .font(.system(size: FontSize.xs))
        }
      }
      .foregroundStyle(Track.regionTextColor)

      RoundedRectangle(cornerRadius: Track.borderRadius)
        .strokeBorder(Track.borderColor, lineWidth: Track.borderWidth)
    }
    .frame(width: regionWidth, height: height)
    .clipShape(RoundedRectangle(cornerRadius: Track.borderRadius))
    .contentShape(Rectangle())
    .overlay {
      RightClickOverlay {
        popoverSpotlightRegionId = region.id
      }
    }
    .popover(
      isPresented: Binding(
        get: { isPopoverShown },
        set: { if !$0 { popoverSpotlightRegionId = nil } }
      ),
      arrowEdge: .top
    ) {
      SpotlightRegionEditPopover(
        region: region,
        globalRadius: editorState.spotlightRadius,
        globalDimOpacity: editorState.spotlightDimOpacity,
        globalEdgeSoftness: editorState.spotlightEdgeSoftness,
        onUpdateStyle: { radius, dimOpacity, edgeSoftness, fadeDuration in
          editorState.updateSpotlightRegionStyle(
            regionId: region.id,
            radius: radius,
            dimOpacity: dimOpacity,
            edgeSoftness: edgeSoftness,
            fadeDuration: fadeDuration
          )
        },
        onRemove: {
          popoverSpotlightRegionId = nil
          editorState.removeSpotlightRegion(regionId: region.id)
        }
      )
      .presentationBackground(ReframedColors.backgroundPopover)
    }
    .gesture(
      DragGesture(minimumDistance: 3, coordinateSpace: .named("spotlightRegion"))
        .onChanged { value in
          if spotlightDragType == nil {
            let origStartX = CGFloat(region.startSeconds / totalSeconds) * width
            let origEndX = CGFloat(region.endSeconds / totalSeconds) * width
            let origWidth = origEndX - origStartX
            let relX = value.startLocation.x - origStartX
            let effectiveEdge = min(8.0, origWidth * 0.2)
            if relX <= effectiveEdge {
              spotlightDragType = .resizeLeft
            } else if relX >= origWidth - effectiveEdge {
              spotlightDragType = .resizeRight
            } else {
              spotlightDragType = .move
            }
            spotlightDragRegionId = region.id
          }
          spotlightDragOffset = value.translation.width
        }
        .onEnded { _ in
          guard spotlightDragType != nil else { return }
          commitSpotlightDrag(region: region, width: width)
          spotlightDragOffset = 0
          spotlightDragType = nil
          spotlightDragRegionId = nil
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

  func effectiveSpotlightRegion(_ region: SpotlightRegionData, width: CGFloat) -> (start: Double, end: Double) {
    guard spotlightDragRegionId == region.id, let dt = spotlightDragType else {
      return (region.startSeconds, region.endSeconds)
    }
    let timeDelta = (spotlightDragOffset / width) * totalSeconds
    let regions = editorState.spotlightRegions
    guard let idx = regions.firstIndex(where: { $0.id == region.id }) else {
      return (region.startSeconds, region.endSeconds)
    }
    let dur = totalSeconds
    let prevEnd: Double = idx > 0 ? regions[idx - 1].endSeconds : 0
    let nextStart: Double = idx < regions.count - 1 ? regions[idx + 1].startSeconds : dur

    let minDuration = max(0.1, (24.0 / width) * dur)

    switch dt {
    case .move:
      let regionDur = region.endSeconds - region.startSeconds
      let clampedStart = max(prevEnd, min(nextStart - regionDur, region.startSeconds + timeDelta))
      return (clampedStart, clampedStart + regionDur)
    case .resizeLeft:
      let newStart = max(prevEnd, min(region.endSeconds - minDuration, region.startSeconds + timeDelta))
      return (newStart, region.endSeconds)
    case .resizeRight:
      let newEnd = max(region.startSeconds + minDuration, min(nextStart, region.endSeconds + timeDelta))
      return (region.startSeconds, newEnd)
    }
  }

  func commitSpotlightDrag(region: SpotlightRegionData, width: CGFloat) {
    let timeDelta = (spotlightDragOffset / width) * totalSeconds

    switch spotlightDragType {
    case .move:
      editorState.moveSpotlightRegion(regionId: region.id, newStart: region.startSeconds + timeDelta)
    case .resizeLeft:
      editorState.updateSpotlightRegionStart(regionId: region.id, newStart: region.startSeconds + timeDelta)
    case .resizeRight:
      editorState.updateSpotlightRegionEnd(regionId: region.id, newEnd: region.endSeconds + timeDelta)
    case nil:
      break
    }
  }
}
