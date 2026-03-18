import AVFoundation
import AppKit

extension VideoPreviewContainer {
  func updateCursorOverlay(
    normalizedPosition: CGPoint,
    style: CursorStyle,
    size: CGFloat,
    visible: Bool,
    clicks: [(point: CGPoint, progress: Double)],
    clickHighlightColor: CGColor? = nil,
    clickHighlightSize: CGFloat = 36,
    cursorFillColor: CodableColor = CodableColor(r: 1, g: 1, b: 1),
    cursorStrokeColor: CodableColor = CodableColor(r: 0, g: 0, b: 0),
    swayRotation: CGFloat = 0,
    bounceScale: CGFloat = 1.0,
    motionBlurDx: CGFloat = 0,
    motionBlurDy: CGFloat = 0,
    motionBlurMagnitude: CGFloat = 0,
    systemCursorType: SystemCursorType? = nil
  ) {
    lastCursorNormalizedPosition = normalizedPosition
    lastCursorStyle = style
    lastCursorSize = size
    lastCursorVisible = visible
    lastCursorClicks = clicks
    lastClickHighlightColor = clickHighlightColor
    lastClickHighlightSize = clickHighlightSize
    lastCursorFillColor = cursorFillColor
    lastCursorStrokeColor = cursorStrokeColor
    lastSwayRotation = swayRotation
    lastSystemCursorType = systemCursorType
    lastBounceScale = bounceScale
    lastMotionBlurDx = motionBlurDx
    lastMotionBlurDy = motionBlurDy
    lastMotionBlurMagnitude = motionBlurMagnitude

    applyCursorOverlay()
  }

  func applyCursorOverlay() {
    let normalizedPosition = lastCursorNormalizedPosition
    let style = lastCursorStyle
    let size = lastCursorSize
    let visible = lastCursorVisible
    let clicks = lastCursorClicks
    let clickHighlightColor = lastClickHighlightColor
    let clickHighlightSize = lastClickHighlightSize

    let canvasRect = AVMakeRect(aspectRatio: currentCanvasSize, insideRect: bounds)
    let scaleX = canvasRect.width / max(currentCanvasSize.width, 1)
    let scaleY = canvasRect.height / max(currentCanvasSize.height, 1)
    let padH = currentPadding * currentScreenSize.width * scaleX
    let padV = currentPadding * currentScreenSize.height * scaleY

    let paddedArea = CGRect(
      x: canvasRect.origin.x + padH,
      y: canvasRect.origin.y + padV,
      width: canvasRect.width - padH * 2,
      height: canvasRect.height - padV * 2
    )
    let screenRect = AVMakeRect(aspectRatio: currentScreenSize, insideRect: paddedArea)

    let zr = currentZoomRect
    let isZoomed = zr.width < 1.0 || zr.height < 1.0

    func transformPos(_ pos: CGPoint) -> (CGPoint, Bool) {
      var p = pos
      if isZoomed {
        p = CGPoint(x: (p.x - zr.origin.x) / zr.width, y: (p.y - zr.origin.y) / zr.height)
        if p.x < -0.05 || p.x > 1.05 || p.y < -0.05 || p.y > 1.05 {
          return (p, false)
        }
      }
      let pixelX = p.x * screenRect.width
      let pixelY = (1 - p.y) * screenRect.height
      return (CGPoint(x: pixelX, y: pixelY), true)
    }

    let (cursorPixel, cursorVisible) = transformPos(normalizedPosition)

    let adjustedClicks: [(point: CGPoint, progress: Double)] = clicks.compactMap { click in
      let (pixel, vis) = transformPos(click.point)
      guard vis else { return nil }
      return (pixel, click.progress)
    }

    let zoomScale: CGFloat = isZoomed ? 1.0 / zr.width : 1.0
    let baseScale = min(scaleX, scaleY)

    cursorOverlay.update(
      pixelPosition: cursorPixel,
      style: style,
      size: size * baseScale * zoomScale,
      visible: visible && cursorVisible,
      containerSize: screenRect.size,
      clicks: adjustedClicks,
      highlightColor: clickHighlightColor,
      highlightSize: clickHighlightSize * baseScale * zoomScale,
      fillColor: lastCursorFillColor,
      strokeColor: lastCursorStrokeColor,
      swayRotation: lastSwayRotation,
      bounceScale: lastBounceScale,
      systemCursorType: lastSystemCursorType,
      motionBlurDx: lastMotionBlurDx * baseScale,
      motionBlurDy: lastMotionBlurDy * baseScale,
      motionBlurMagnitude: lastMotionBlurMagnitude * baseScale
    )
  }
}
