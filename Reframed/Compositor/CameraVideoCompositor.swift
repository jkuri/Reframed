import AVFoundation
import CoreVideo

final class CameraVideoCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
  var sourcePixelBufferAttributes: [String: any Sendable]? {
    [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_64RGBAHalf]
  }

  var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] {
    [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_64RGBAHalf]
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

    var webcamBuffer: CVPixelBuffer?
    if let webcamTrackID = instruction.webcamTrackID {
      webcamBuffer = request.sourceFrame(byTrackID: webcamTrackID)
    }

    CameraVideoCompositor.renderFrame(
      screenBuffer: screenBuffer,
      webcamBuffer: webcamBuffer,
      outputBuffer: outputBuffer,
      compositionTime: request.compositionTime,
      instruction: instruction
    )

    request.finish(withComposedVideoFrame: outputBuffer)
  }

  static func renderFrame(
    screenBuffer: CVPixelBuffer,
    webcamBuffer: CVPixelBuffer?,
    outputBuffer: CVPixelBuffer,
    compositionTime: CMTime,
    instruction: CompositionInstruction
  ) {
    let width = CVPixelBufferGetWidth(outputBuffer)
    let height = CVPixelBufferGetHeight(outputBuffer)

    CVPixelBufferLockBaseAddress(screenBuffer, .readOnly)
    CVPixelBufferLockBaseAddress(outputBuffer, [])
    if let wb = webcamBuffer { CVPixelBufferLockBaseAddress(wb, .readOnly) }
    defer {
      CVPixelBufferUnlockBaseAddress(screenBuffer, .readOnly)
      CVPixelBufferUnlockBaseAddress(outputBuffer, [])
      if let wb = webcamBuffer { CVPixelBufferUnlockBaseAddress(wb, .readOnly) }
    }

    let is16bit = CVPixelBufferGetPixelFormatType(outputBuffer) == kCVPixelFormatType_64RGBAHalf
    let colorSpace: CGColorSpace
    let bitsPerComponent: Int
    let bitmapInfo: UInt32
    if is16bit {
      colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
      bitsPerComponent = 16
      bitmapInfo =
        CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder16Little.rawValue
        | CGImageAlphaInfo.premultipliedLast.rawValue
    } else {
      colorSpace = CGColorSpaceCreateDeviceRGB()
      bitsPerComponent = 8
      bitmapInfo =
        CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
    }
    guard
      let context = CGContext(
        data: CVPixelBufferGetBaseAddress(outputBuffer),
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bytesPerRow: CVPixelBufferGetBytesPerRow(outputBuffer),
        space: colorSpace,
        bitmapInfo: bitmapInfo
      )
    else {
      return
    }

    context.interpolationQuality = .high

    let canvasRect = CGRect(x: 0, y: 0, width: width, height: height)

    drawBackground(in: context, rect: canvasRect, instruction: instruction, colorSpace: colorSpace)

    let paddedArea = CGRect(
      x: instruction.paddingH,
      y: instruction.paddingV,
      width: CGFloat(width) - 2 * instruction.paddingH,
      height: CGFloat(height) - 2 * instruction.paddingV
    )

    let screenImage = createImage(from: screenBuffer, colorSpace: colorSpace)
    if let img = screenImage {
      let screenAspect = CGSize(width: img.width, height: img.height)
      let videoRect = AVMakeRect(aspectRatio: screenAspect, insideRect: paddedArea)

      if instruction.videoShadow > 0 {
        let blur = min(videoRect.width, videoRect.height) * instruction.videoShadow / 2000.0
        context.saveGState()
        context.setShadow(
          offset: .zero,
          blur: blur,
          color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.6)
        )
        if instruction.videoCornerRadius > 0 {
          let shadowPath = CGPath(
            roundedRect: videoRect,
            cornerWidth: instruction.videoCornerRadius,
            cornerHeight: instruction.videoCornerRadius,
            transform: nil
          )
          context.addPath(shadowPath)
        } else {
          context.addRect(videoRect)
        }
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fillPath()
        context.restoreGState()
      }

      let metadataTime = CMTimeGetSeconds(compositionTime) + instruction.trimStartSeconds
      var zoomRect = instruction.zoomTimeline?.zoomRect(at: metadataTime)
      if instruction.zoomFollowCursor, let zr = zoomRect, zr.width < 1.0 || zr.height < 1.0,
        let snapshot = instruction.cursorSnapshot
      {
        let cursorPos = snapshot.sample(at: metadataTime)
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
          y: videoRect.origin.y - (1 - zr.origin.y - zr.height) * srcH * scaleY,
          width: srcW * scaleX,
          height: srcH * scaleY
        )
        if instruction.videoCornerRadius <= 0 {
          context.clip(to: videoRect)
        }
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

        let cursorPos = snapshot.sample(at: metadataTime)

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
        let zoomScale: CGFloat = {
          if let zr = zoomRect, zr.width < 1.0 { return 1.0 / zr.width }
          return 1.0
        }()

        CursorRenderer.drawCursor(
          in: context,
          position: CGPoint(x: pixelX, y: pixelY),
          style: instruction.cursorStyle,
          size: instruction.cursorSize * drawScale * zoomScale
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
              size: instruction.clickHighlightSize * drawScale * zoomScale,
              color: instruction.clickHighlightColor
            )
          }
        }

        context.restoreGState()
      }
    }

    if let webcamBuffer {
      let isCamFullscreen = instruction.cameraFullscreenRegions.contains {
        $0.containsTime(compositionTime)
      }

      let webcamImage = createImage(from: webcamBuffer, colorSpace: colorSpace)

      if let webcamImage {
        if isCamFullscreen {
          let fullRect = CGRect(x: 0, y: 0, width: width, height: height)
          let targetAspect = instruction.cameraFullscreenAspect.aspectRatio(
            webcamSize: CGSize(width: webcamImage.width, height: webcamImage.height)
          )
          let virtualSize: CGSize
          if instruction.cameraFullscreenAspect == .original {
            virtualSize = CGSize(width: webcamImage.width, height: webcamImage.height)
          } else {
            virtualSize = CGSize(width: targetAspect * 1000, height: 1000)
          }
          let drawRect: CGRect
          switch instruction.cameraFullscreenFillMode {
          case .fit:
            drawRect = AVMakeRect(aspectRatio: virtualSize, insideRect: fullRect)
          case .fill:
            drawRect = aspectFillRect(imageSize: virtualSize, in: fullRect)
          }
          context.saveGState()
          drawBackground(in: context, rect: fullRect, instruction: instruction, colorSpace: colorSpace)
          context.clip(to: fullRect)
          if instruction.cameraMirrored {
            context.translateBy(x: drawRect.midX, y: 0)
            context.scaleBy(x: -1, y: 1)
            context.translateBy(x: -drawRect.midX, y: 0)
          }
          if instruction.cameraFullscreenAspect == .original {
            context.draw(webcamImage, in: drawRect)
          } else {
            let imgFill = aspectFillRect(
              imageSize: CGSize(width: webcamImage.width, height: webcamImage.height),
              in: drawRect
            )
            context.clip(to: drawRect)
            context.draw(webcamImage, in: imgFill)
          }
          context.restoreGState()
        } else if let cameraRect = instruction.cameraRect {
          let flippedY = CGFloat(height) - cameraRect.origin.y - cameraRect.height
          let drawRect = CGRect(
            x: cameraRect.origin.x,
            y: flippedY,
            width: cameraRect.width,
            height: cameraRect.height
          )

          if instruction.cameraShadow > 0 {
            let blur = min(drawRect.width, drawRect.height) * instruction.cameraShadow / 2000.0
            context.saveGState()
            context.setShadow(
              offset: .zero,
              blur: blur,
              color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.6)
            )
            let shadowPath = CGPath(
              roundedRect: drawRect,
              cornerWidth: instruction.cameraCornerRadius,
              cornerHeight: instruction.cameraCornerRadius,
              transform: nil
            )
            context.addPath(shadowPath)
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            context.fillPath()
            context.restoreGState()
          }

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
            context.setFillColor(instruction.cameraBorderColor)
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
            if instruction.cameraMirrored {
              context.translateBy(x: insetRect.midX, y: 0)
              context.scaleBy(x: -1, y: 1)
              context.translateBy(x: -insetRect.midX, y: 0)
            }
            let innerFill = aspectFillRect(imageSize: CGSize(width: webcamImage.width, height: webcamImage.height), in: insetRect)
            context.draw(webcamImage, in: innerFill)
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
            if instruction.cameraMirrored {
              context.translateBy(x: drawRect.midX, y: 0)
              context.scaleBy(x: -1, y: 1)
              context.translateBy(x: -drawRect.midX, y: 0)
            }
            let fillRect = aspectFillRect(imageSize: CGSize(width: webcamImage.width, height: webcamImage.height), in: drawRect)
            context.draw(webcamImage, in: fillRect)
            context.restoreGState()
          }
        }
      }
    }
  }

  private static func aspectFillRect(imageSize: CGSize, in rect: CGRect) -> CGRect {
    let imageAspect = imageSize.width / max(imageSize.height, 1)
    let rectAspect = rect.width / max(rect.height, 1)
    if imageAspect > rectAspect {
      let w = rect.height * imageAspect
      return CGRect(x: rect.midX - w / 2, y: rect.origin.y, width: w, height: rect.height)
    } else {
      let h = rect.width / max(imageAspect, 0.001)
      return CGRect(x: rect.origin.x, y: rect.midY - h / 2, width: rect.width, height: h)
    }
  }

  private static func drawBackground(
    in context: CGContext,
    rect: CGRect,
    instruction: CompositionInstruction,
    colorSpace: CGColorSpace
  ) {
    if let bgImage = instruction.backgroundImage {
      context.saveGState()
      context.addRect(rect)
      context.clip()
      let imageAspect = CGFloat(bgImage.width) / CGFloat(max(bgImage.height, 1))
      let rectAspect = rect.width / max(rect.height, 1)
      let drawRect: CGRect
      switch instruction.backgroundImageFillMode {
      case .fill:
        if imageAspect > rectAspect {
          let w = rect.height * imageAspect
          drawRect = CGRect(x: rect.midX - w / 2, y: rect.origin.y, width: w, height: rect.height)
        } else {
          let h = rect.width / max(imageAspect, 0.001)
          drawRect = CGRect(x: rect.origin.x, y: rect.midY - h / 2, width: rect.width, height: h)
        }
      case .fit:
        if imageAspect > rectAspect {
          let h = rect.width / max(imageAspect, 0.001)
          drawRect = CGRect(x: rect.origin.x, y: rect.midY - h / 2, width: rect.width, height: h)
        } else {
          let w = rect.height * imageAspect
          drawRect = CGRect(x: rect.midX - w / 2, y: rect.origin.y, width: w, height: rect.height)
        }
      }
      context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
      context.fill([rect])
      context.draw(bgImage, in: drawRect)
      context.restoreGState()
      return
    }

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

  private static func createImage(from pixelBuffer: CVPixelBuffer, colorSpace: CGColorSpace) -> CGImage? {
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

    let is16bit = CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_64RGBAHalf
    let bitsPerComponent: Int
    let bitmapInfo: UInt32
    let imageColorSpace: CGColorSpace
    if is16bit {
      bitsPerComponent = 16
      bitmapInfo =
        CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder16Little.rawValue
        | CGImageAlphaInfo.premultipliedLast.rawValue
      imageColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    } else {
      bitsPerComponent = 8
      bitmapInfo =
        CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
      imageColorSpace = colorSpace
    }

    guard
      let ctx = CGContext(
        data: baseAddress,
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bytesPerRow: bytesPerRow,
        space: imageColorSpace,
        bitmapInfo: bitmapInfo
      )
    else { return nil }

    return ctx.makeImage()
  }
}
