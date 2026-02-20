import SwiftUI

extension TimelineView {
  func cameraTrackContent(width: CGFloat) -> some View {
    let h = trackHeight
    let regions = editorState.cameraRegions

    return ZStack(alignment: .leading) {
      ForEach(regions) { region in
        cameraRegionView(
          region: region,
          width: width,
          height: h
        )
      }

      if regions.isEmpty {
        let viewportWidth = width / timelineZoom
        let visibleCenterX = scrollOffset + viewportWidth / 2
        Text("Double-click to add camera region")
          .font(.system(size: 11))
          .foregroundStyle(ReframedColors.dimLabel)
          .fixedSize()
          .position(x: visibleCenterX, y: h / 2)
          .allowsHitTesting(false)
      }
    }
    .frame(width: width, height: h)
    .clipped()
    .coordinateSpace(name: "cameraRegion")
    .contentShape(Rectangle())
    .onTapGesture(count: 2) { location in
      let time = (location.x / width) * totalSeconds
      let hitRegion = regions.first { r in
        let eff = effectiveCameraRegion(r, width: width)
        let startX = (eff.start / totalSeconds) * width
        let endX = (eff.end / totalSeconds) * width
        return location.x >= startX && location.x <= endX
      }
      if hitRegion == nil {
        editorState.addCameraRegion(atTime: time)
      }
    }
  }

  @ViewBuilder
  func cameraRegionView(
    region: CameraRegionData,
    width: CGFloat,
    height: CGFloat
  ) -> some View {
    let accentColor: Color =
      switch region.type {
      case .fullscreen: ReframedColors.webcamTrackColor
      case .hidden: ReframedColors.webcamHiddenTrackColor
      case .custom: ReframedColors.webcamCustomTrackColor
      }
    let effective = effectiveCameraRegion(region, width: width)
    let startX = max(0, CGFloat(effective.start / totalSeconds) * width)
    let endX = min(width, CGFloat(effective.end / totalSeconds) * width)
    let regionWidth = max(4, endX - startX)
    let edgeThreshold = min(8.0, regionWidth * 0.2)
    let isPopoverShown = popoverCameraRegionId == region.id

    ZStack {
      RoundedRectangle(cornerRadius: 6)
        .fill(accentColor.opacity(0.6))

      RoundedRectangle(cornerRadius: 6)
        .strokeBorder(accentColor, lineWidth: 2)
    }
    .frame(width: regionWidth, height: height)
    .contentShape(Rectangle())
    .overlay {
      RightClickOverlay {
        popoverCameraRegionId = region.id
      }
    }
    .popover(
      isPresented: Binding(
        get: { isPopoverShown },
        set: { if !$0 { popoverCameraRegionId = nil } }
      ),
      arrowEdge: .top
    ) {
      CameraRegionEditPopover(
        region: region,
        maxCameraRelativeWidth: editorState.maxCameraRelativeWidth,
        onChangeType: { newType in
          editorState.updateCameraRegionType(regionId: region.id, type: newType)
        },
        onUpdateLayout: { layout in
          editorState.updateCameraRegionLayout(regionId: region.id, layout: layout)
          editorState.clampCameraRegionLayout(regionId: region.id)
        },
        onSetCorner: { corner in
          editorState.setCameraRegionCorner(regionId: region.id, corner: corner)
        },
        onUpdateStyle: { aspect, cornerRadius, shadow, borderWidth, borderColor, mirrored in
          editorState.updateCameraRegionStyle(
            regionId: region.id,
            aspect: aspect,
            cornerRadius: cornerRadius,
            shadow: shadow,
            borderWidth: borderWidth,
            borderColor: borderColor,
            mirrored: mirrored
          )
        },
        onRemove: {
          popoverCameraRegionId = nil
          editorState.removeCameraRegion(regionId: region.id)
        }
      )
      .presentationBackground(ReframedColors.panelBackground)
    }
    .gesture(
      DragGesture(minimumDistance: 3, coordinateSpace: .named("cameraRegion"))
        .onChanged { value in
          if cameraDragType == nil {
            let origStartX = CGFloat(region.startSeconds / totalSeconds) * width
            let origEndX = CGFloat(region.endSeconds / totalSeconds) * width
            let origWidth = origEndX - origStartX
            let relX = value.startLocation.x - origStartX
            let effectiveEdge = min(8.0, origWidth * 0.2)
            if relX <= effectiveEdge {
              cameraDragType = .resizeLeft
            } else if relX >= origWidth - effectiveEdge {
              cameraDragType = .resizeRight
            } else {
              cameraDragType = .move
            }
            cameraDragRegionId = region.id
          }
          cameraDragOffset = value.translation.width
        }
        .onEnded { _ in
          guard cameraDragType != nil else { return }
          commitCameraDrag(region: region, width: width)
          cameraDragOffset = 0
          cameraDragType = nil
          cameraDragRegionId = nil
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

  func effectiveCameraRegion(_ region: CameraRegionData, width: CGFloat) -> (start: Double, end: Double) {
    guard cameraDragRegionId == region.id, let dt = cameraDragType else {
      return (region.startSeconds, region.endSeconds)
    }
    let timeDelta = (cameraDragOffset / width) * totalSeconds

    switch dt {
    case .move:
      return (region.startSeconds + timeDelta, region.endSeconds + timeDelta)
    case .resizeLeft:
      return (region.startSeconds + timeDelta, region.endSeconds)
    case .resizeRight:
      return (region.startSeconds, region.endSeconds + timeDelta)
    }
  }

  func commitCameraDrag(region: CameraRegionData, width: CGFloat) {
    let timeDelta = (cameraDragOffset / width) * totalSeconds

    switch cameraDragType {
    case .move:
      editorState.moveCameraRegion(regionId: region.id, newStart: region.startSeconds + timeDelta)
    case .resizeLeft:
      editorState.updateCameraRegionStart(regionId: region.id, newStart: region.startSeconds + timeDelta)
    case .resizeRight:
      editorState.updateCameraRegionEnd(regionId: region.id, newEnd: region.endSeconds + timeDelta)
    case nil:
      break
    }
  }

  func buildWaveformPath(top: [CGPoint], bottom: [CGPoint], minX: CGFloat, maxX: CGFloat) -> Path {
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
}
