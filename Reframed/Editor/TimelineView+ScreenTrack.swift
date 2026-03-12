import AVFoundation
import SwiftUI

extension TimelineView {
  func screenTrackContent(width: CGFloat) -> some View {
    let h = trackHeight
    let regions = editorState.videoRegions

    return ZStack(alignment: .leading) {
      ForEach(regions) { region in
        videoRegionView(
          region: region,
          width: width,
          height: h
        )
      }
    }
    .frame(width: width, height: h)
    .clipped()
    .coordinateSpace(name: "videoRegion")
    .contentShape(Rectangle())
    .onTapGesture(count: 2) { location in
      let time = (location.x / width) * totalSeconds
      editorState.addVideoRegion(atTime: time)
    }
  }

  @ViewBuilder
  func videoRegionView(
    region: VideoRegionData,
    width: CGFloat,
    height: CGFloat
  ) -> some View {
    let effective = effectiveVideoRegion(region, width: width)
    let startX = max(0, CGFloat(effective.start / totalSeconds) * width)
    let endX = min(width, CGFloat(effective.end / totalSeconds) * width)
    let regionWidth = max(4, endX - startX)
    let edgeThreshold = min(8.0, regionWidth * 0.2)
    let isPopoverShown = popoverVideoRegionId == region.id

    ZStack {
      RoundedRectangle(cornerRadius: Track.borderRadius)
        .fill(Track.background)

      HStack(spacing: 3) {
        Image(systemName: "film")
          .font(.system(size: Track.fontSize))
        if regionWidth > 50 {
          Text(formatTimeRange(start: effective.start, end: effective.end))
            .font(.system(size: Track.fontSize, weight: Track.fontWeight))
            .lineLimit(1)
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
        popoverVideoRegionId = region.id
      }
    }
    .popover(
      isPresented: Binding(
        get: { isPopoverShown },
        set: { if !$0 { popoverVideoRegionId = nil } }
      ),
      arrowEdge: .top
    ) {
      VideoRegionEditPopover(
        region: region,
        canRemove: editorState.videoRegions.count > 1,
        onUpdateTransition: { entryType, entryDur, exitType, exitDur in
          editorState.updateVideoRegionTransition(
            regionId: region.id,
            entryTransition: entryType,
            entryDuration: entryDur,
            exitTransition: exitType,
            exitDuration: exitDur
          )
        },
        onRemove: {
          popoverVideoRegionId = nil
          editorState.removeVideoRegion(regionId: region.id)
        }
      )
      .presentationBackground(ReframedColors.backgroundPopover)
    }
    .gesture(
      DragGesture(minimumDistance: 3, coordinateSpace: .named("videoRegion"))
        .onChanged { value in
          if videoDragType == nil {
            let origStartX = CGFloat(region.startSeconds / totalSeconds) * width
            let origEndX = CGFloat(region.endSeconds / totalSeconds) * width
            let origWidth = origEndX - origStartX
            let relX = value.startLocation.x - origStartX
            let effectiveEdge = min(8.0, origWidth * 0.2)
            if relX <= effectiveEdge {
              videoDragType = .resizeLeft
            } else if relX >= origWidth - effectiveEdge {
              videoDragType = .resizeRight
            } else {
              videoDragType = .move
            }
            videoDragRegionId = region.id
          }
          videoDragOffset = value.translation.width
        }
        .onEnded { _ in
          guard videoDragType != nil else { return }
          commitVideoDrag(region: region, width: width)
          videoDragOffset = 0
          videoDragType = nil
          videoDragRegionId = nil
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

  func effectiveVideoRegion(_ region: VideoRegionData, width: CGFloat) -> (start: Double, end: Double) {
    guard videoDragRegionId == region.id, let dt = videoDragType else {
      return (region.startSeconds, region.endSeconds)
    }
    let timeDelta = (videoDragOffset / width) * totalSeconds
    let regions = editorState.videoRegions
    guard let idx = regions.firstIndex(where: { $0.id == region.id }) else {
      return (region.startSeconds, region.endSeconds)
    }
    let prevEnd: Double = idx > 0 ? regions[idx - 1].endSeconds : 0
    let nextStart: Double = idx < regions.count - 1 ? regions[idx + 1].startSeconds : totalSeconds

    let minDuration = max(0.1, (24.0 / width) * totalSeconds)

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

  func commitVideoDrag(region: VideoRegionData, width: CGFloat) {
    let timeDelta = (videoDragOffset / width) * totalSeconds

    switch videoDragType {
    case .move:
      editorState.moveVideoRegion(regionId: region.id, newStart: region.startSeconds + timeDelta)
    case .resizeLeft:
      editorState.updateVideoRegionStart(regionId: region.id, newStart: region.startSeconds + timeDelta)
    case .resizeRight:
      editorState.updateVideoRegionEnd(regionId: region.id, newEnd: region.endSeconds + timeDelta)
    case nil:
      break
    }
  }

}
