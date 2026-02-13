import AVFoundation
import CoreVideo

final class CameraVideoCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
  var sourcePixelBufferAttributes: [String: any Sendable]? {
    [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
  }

  var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] {
    [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
  }

  func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

  func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
    guard let instruction = request.videoCompositionInstruction as? CompositionInstruction else {
      request.finish(with: NSError(domain: "CameraVideoCompositor", code: -1))
      return
    }

    guard let screenBuffer = request.sourceFrame(byTrackID: instruction.screenTrackID) else {
      request.finish(with: NSError(domain: "CameraVideoCompositor", code: -2))
      return
    }

    guard let outputBuffer = request.renderContext.newPixelBuffer() else {
      request.finish(with: NSError(domain: "CameraVideoCompositor", code: -3))
      return
    }

    let width = CVPixelBufferGetWidth(outputBuffer)
    let height = CVPixelBufferGetHeight(outputBuffer)

    CVPixelBufferLockBaseAddress(screenBuffer, .readOnly)
    CVPixelBufferLockBaseAddress(outputBuffer, [])
    defer {
      CVPixelBufferUnlockBaseAddress(screenBuffer, .readOnly)
      CVPixelBufferUnlockBaseAddress(outputBuffer, [])
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard
      let context = CGContext(
        data: CVPixelBufferGetBaseAddress(outputBuffer),
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(outputBuffer),
        space: colorSpace,
        bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
      )
    else {
      request.finish(with: NSError(domain: "CameraVideoCompositor", code: -4))
      return
    }

    let canvasRect = CGRect(x: 0, y: 0, width: width, height: height)

    drawBackground(in: context, rect: canvasRect, instruction: instruction, colorSpace: colorSpace)

    let videoRect = CGRect(
      x: instruction.paddingH,
      y: instruction.paddingV,
      width: CGFloat(width) - 2 * instruction.paddingH,
      height: CGFloat(height) - 2 * instruction.paddingV
    )

    let screenImage = createImage(from: screenBuffer, colorSpace: colorSpace)
    if let img = screenImage {
      let metadataTime = CMTimeGetSeconds(request.compositionTime) + instruction.trimStartSeconds
      var zoomRect = instruction.zoomTimeline?.zoomRect(at: metadataTime)
      if instruction.zoomFollowCursor, let zr = zoomRect, zr.width < 1.0 || zr.height < 1.0,
        let snapshot = instruction.cursorSnapshot
      {
        let cursorPos = snapshot.sample(at: metadataTime, smoothing: instruction.cursorSmoothing)
        zoomRect = ZoomTimeline.followCursor(zr, cursorPosition: cursorPos)
      }
      context.saveGState()
      if instruction.videoCornerRadius > 0 {
        let path = CGPath(
          roundedRect: videoRect,
          cornerWidth: instruction.videoCornerRadius,
          cornerHeight: instruction.videoCornerRadius,
          transform: nil
        )
        context.addPath(path)
        context.clip()
      }

      if let zr = zoomRect, zr.width < 1.0 || zr.height < 1.0 {
        let srcW = CGFloat(img.width)
        let srcH = CGFloat(img.height)
        let scaleX = videoRect.width / (zr.width * srcW)
        let scaleY = videoRect.height / (zr.height * srcH)
        let drawRect = CGRect(
          x: videoRect.origin.x - zr.origin.x * srcW * scaleX,
          y: videoRect.origin.y - zr.origin.y * srcH * scaleY,
          width: srcW * scaleX,
          height: srcH * scaleY
        )
        if instruction.videoCornerRadius <= 0 {
          context.clip(to: videoRect)
        }
        context.interpolationQuality = .high
        context.draw(img, in: drawRect)
      } else {
        context.draw(img, in: videoRect)
      }
      context.restoreGState()

      if instruction.showCursor, let snapshot = instruction.cursorSnapshot {
        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        let flippedVideoRect = CGRect(
          x: videoRect.origin.x,
          y: CGFloat(height) - videoRect.origin.y - videoRect.height,
          width: videoRect.width,
          height: videoRect.height
        )

        let cursorPos = snapshot.sample(at: metadataTime, smoothing: instruction.cursorSmoothing)

        var pixelX: CGFloat
        var pixelY: CGFloat

        if let zr = zoomRect, zr.width < 1.0 || zr.height < 1.0 {
          let relX = (cursorPos.x - zr.origin.x) / zr.width
          let relY = (cursorPos.y - zr.origin.y) / zr.height
          pixelX = flippedVideoRect.origin.x + relX * flippedVideoRect.width
          pixelY = flippedVideoRect.origin.y + relY * flippedVideoRect.height
        } else {
          pixelX = flippedVideoRect.origin.x + cursorPos.x * flippedVideoRect.width
          pixelY = flippedVideoRect.origin.y + cursorPos.y * flippedVideoRect.height
        }

        let drawScale = flippedVideoRect.width / max(CGFloat(img.width), 1)

        CursorRenderer.drawCursor(
          in: context,
          position: CGPoint(x: pixelX, y: pixelY),
          style: instruction.cursorStyle,
          size: instruction.cursorSize * drawScale
        )

        if instruction.showClickHighlights {
          let clicks = snapshot.activeClicks(at: metadataTime)
          for (clickPoint, progress) in clicks {
            var clickPixelX: CGFloat
            var clickPixelY: CGFloat

            if let zr = zoomRect, zr.width < 1.0 || zr.height < 1.0 {
              let relX = (clickPoint.x - zr.origin.x) / zr.width
              let relY = (clickPoint.y - zr.origin.y) / zr.height
              clickPixelX = flippedVideoRect.origin.x + relX * flippedVideoRect.width
              clickPixelY = flippedVideoRect.origin.y + relY * flippedVideoRect.height
            } else {
              clickPixelX = flippedVideoRect.origin.x + clickPoint.x * flippedVideoRect.width
              clickPixelY = flippedVideoRect.origin.y + clickPoint.y * flippedVideoRect.height
            }

            CursorRenderer.drawClickHighlight(
              in: context,
              position: CGPoint(x: clickPixelX, y: clickPixelY),
              progress: progress,
              size: instruction.clickHighlightSize * drawScale,
              color: instruction.clickHighlightColor
            )
          }
        }

        context.restoreGState()
      }
    }

    if let webcamTrackID = instruction.webcamTrackID,
      let webcamBuffer = request.sourceFrame(byTrackID: webcamTrackID),
      let cameraRect = instruction.cameraRect
    {
      CVPixelBufferLockBaseAddress(webcamBuffer, .readOnly)
      defer { CVPixelBufferUnlockBaseAddress(webcamBuffer, .readOnly) }

      if let webcamImage = createImage(from: webcamBuffer, colorSpace: colorSpace) {
        let adjustedCameraRect = CGRect(
          x: cameraRect.origin.x + instruction.paddingH,
          y: cameraRect.origin.y + instruction.paddingV,
          width: cameraRect.width,
          height: cameraRect.height
        )
        let flippedY = CGFloat(height) - adjustedCameraRect.origin.y - adjustedCameraRect.height
        let drawRect = CGRect(
          x: adjustedCameraRect.origin.x,
          y: flippedY,
          width: adjustedCameraRect.width,
          height: adjustedCameraRect.height
        )

        let bw = instruction.cameraBorderWidth
        if bw > 0 {
          let borderPath = CGPath(
            roundedRect: drawRect,
            cornerWidth: instruction.cameraCornerRadius,
            cornerHeight: instruction.cameraCornerRadius,
            transform: nil
          )
          context.saveGState()
          context.addPath(borderPath)
          context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.3))
          context.fillPath()
          context.restoreGState()

          let insetRect = drawRect.insetBy(dx: bw, dy: bw)
          let innerRadius = max(0, instruction.cameraCornerRadius - bw)
          let innerPath = CGPath(
            roundedRect: insetRect,
            cornerWidth: innerRadius,
            cornerHeight: innerRadius,
            transform: nil
          )
          context.saveGState()
          context.addPath(innerPath)
          context.clip()
          context.draw(webcamImage, in: insetRect)
          context.restoreGState()
        } else {
          let path = CGPath(
            roundedRect: drawRect,
            cornerWidth: instruction.cameraCornerRadius,
            cornerHeight: instruction.cameraCornerRadius,
            transform: nil
          )
          context.saveGState()
          context.addPath(path)
          context.clip()
          context.draw(webcamImage, in: drawRect)
          context.restoreGState()
        }
      }
    }

    request.finish(withComposedVideoFrame: outputBuffer)
  }

  private func drawBackground(
    in context: CGContext,
    rect: CGRect,
    instruction: CompositionInstruction,
    colorSpace: CGColorSpace
  ) {
    let colors = instruction.backgroundColors
    guard !colors.isEmpty else {
      context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
      context.fill([rect])
      return
    }

    if colors.count == 1 {
      let c = colors[0]
      context.setFillColor(CGColor(red: c.r, green: c.g, blue: c.b, alpha: c.a))
      context.fill([rect])
      return
    }

    let cgColors = colors.map { CGColor(red: $0.r, green: $0.g, blue: $0.b, alpha: $0.a) }
    let locations: [CGFloat] = colors.enumerated().map { i, _ in
      CGFloat(i) / CGFloat(max(colors.count - 1, 1))
    }

    guard
      let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: cgColors as CFArray,
        locations: locations
      )
    else {
      context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
      context.fill([rect])
      return
    }

    let startPoint = CGPoint(
      x: rect.width * instruction.backgroundStartPoint.x,
      y: rect.height * instruction.backgroundStartPoint.y
    )
    let endPoint = CGPoint(
      x: rect.width * instruction.backgroundEndPoint.x,
      y: rect.height * instruction.backgroundEndPoint.y
    )

    context.saveGState()
    context.addRect(rect)
    context.clip()
    context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
    context.restoreGState()
  }

  private func createImage(from pixelBuffer: CVPixelBuffer, colorSpace: CGColorSpace) -> CGImage? {
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

    guard
      let ctx = CGContext(
        data: baseAddress,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
      )
    else { return nil }

    return ctx.makeImage()
  }
}
