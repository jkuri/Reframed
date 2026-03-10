import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreVideo
import VideoToolbox

extension FrameRenderer {
  static let hdrCIContext: CIContext = {
    CIContext(options: [
      .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!,
      .cacheIntermediates: false,
    ])
  }()

  static let hdrOutputColorSpace = CGColorSpace(name: CGColorSpace.extendedDisplayP3)!

  static func renderFrameHDR(
    screenBuffer: CVPixelBuffer,
    webcamBuffer: CVPixelBuffer?,
    outputBuffer: CVPixelBuffer,
    compositionTime: CMTime,
    instruction: CompositionInstruction,
    processedWebcamImage: CGImage?,
    state: FrameState
  ) {
    var result = hdrBackground(rect: state.canvasRect, instruction: instruction)

    if instruction.videoShadow > 0 && !state.isScreenTransitioning {
      let shadow = hdrShadow(
        rect: state.videoRect,
        cornerRadius: instruction.videoCornerRadius,
        shadow: instruction.videoShadow
      )
      result = shadow.composited(over: result)
    }

    let screenCI = CIImage(cvPixelBuffer: screenBuffer)
    var screenLayer = hdrPositionScreen(
      screenCI,
      in: state.videoRect,
      instruction: instruction,
      compositionTime: compositionTime
    )

    if let st = state.screenTransition {
      screenLayer = hdrApplyTransition(
        to: screenLayer,
        type: st.type,
        progress: st.progress,
        canvasSize: state.canvasRect.size
      )
    }

    result = screenLayer.composited(over: result)

    if state.screenTransition == nil {
      result = hdrRenderScreenOverlays(
        over: result,
        screenBuffer: screenBuffer,
        videoRect: state.videoRect,
        instruction: instruction,
        compositionTime: compositionTime,
        outputWidth: state.width,
        outputHeight: state.height
      )
    }

    if let webcamBuffer {
      if state.webcamFullyHidden {
        result = hdrRenderCaptions(
          over: result,
          videoRect: state.videoRect,
          instruction: instruction,
          compositionTime: compositionTime,
          outputWidth: state.width,
          outputHeight: state.height
        )
        hdrCIContext.render(
          result.cropped(to: state.canvasRect),
          to: outputBuffer,
          bounds: state.canvasRect,
          colorSpace: hdrOutputColorSpace
        )
        return
      }

      let webcamCI: CIImage? = {
        if let processed = processedWebcamImage {
          return CIImage(cgImage: processed)
        }
        return CIImage(cvPixelBuffer: webcamBuffer)
      }()

      if let webcamCI {
        let regionTransition: (type: RegionTransitionType, progress: CGFloat)? =
          state.webcamRegionTransition.map { ($0.type, $0.progress) }
        result = hdrComposeWebcam(
          webcamImage: webcamCI,
          over: result,
          instruction: instruction,
          compositionTime: compositionTime,
          outputWidth: state.width,
          outputHeight: state.height,
          isCamFullscreen: state.isCamFullscreen,
          regionTransition: regionTransition
        )
      }
    }

    result = hdrRenderCaptions(
      over: result,
      videoRect: state.videoRect,
      instruction: instruction,
      compositionTime: compositionTime,
      outputWidth: state.width,
      outputHeight: state.height
    )

    hdrCIContext.render(
      result.cropped(to: state.canvasRect),
      to: outputBuffer,
      bounds: state.canvasRect,
      colorSpace: hdrOutputColorSpace
    )
  }

  // MARK: - Background

  private static func hdrBackground(rect: CGRect, instruction: CompositionInstruction) -> CIImage {
    if let bgImage = instruction.backgroundImage {
      let bg = CIImage(color: CIColor.black).cropped(to: rect)
      let imgCI = CIImage(cgImage: bgImage)
      let drawRect = backgroundImageRect(
        imageSize: CGSize(width: bgImage.width, height: bgImage.height),
        in: rect,
        fillMode: instruction.backgroundImageFillMode
      )
      let scaleX = drawRect.width / imgCI.extent.width
      let scaleY = drawRect.height / imgCI.extent.height
      let scaled = imgCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        .transformed(by: CGAffineTransform(translationX: drawRect.origin.x, y: drawRect.origin.y))
        .cropped(to: rect)
      return scaled.composited(over: bg)
    }

    let colors = instruction.backgroundColors
    guard !colors.isEmpty else {
      return CIImage(color: CIColor.black).cropped(to: rect)
    }

    if colors.count == 1 {
      let c = colors[0]
      return CIImage(color: CIColor(red: c.r, green: c.g, blue: c.b, alpha: c.a)).cropped(to: rect)
    }

    guard
      let ctx = CGContext(
        data: nil,
        width: Int(rect.width),
        height: Int(rect.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
      )
    else {
      return CIImage(color: CIColor.black).cropped(to: rect)
    }

    let localRect = CGRect(origin: .zero, size: rect.size)
    if let resolved = makeBackgroundGradient(
      colors: colors,
      rectSize: rect.size,
      startPoint: instruction.backgroundStartPoint,
      endPoint: instruction.backgroundEndPoint,
      colorSpace: CGColorSpaceCreateDeviceRGB()
    ) {
      ctx.addRect(localRect)
      ctx.clip()
      ctx.drawLinearGradient(resolved.gradient, start: resolved.startPoint, end: resolved.endPoint, options: [])
    }

    guard let cgImage = ctx.makeImage() else {
      return CIImage(color: CIColor.black).cropped(to: rect)
    }
    return CIImage(cgImage: cgImage)
  }

  // MARK: - Screen Positioning

  private static func hdrPositionScreen(
    _ screenImage: CIImage,
    in videoRect: CGRect,
    instruction: CompositionInstruction,
    compositionTime: CMTime
  ) -> CIImage {
    let srcW = screenImage.extent.width
    let srcH = screenImage.extent.height

    let zoomRect = resolveZoomRect(compositionTime: compositionTime, instruction: instruction)

    var image = screenImage

    if let zr = zoomRect, zr.width < 1.0 || zr.height < 1.0 {
      let cropRect = CGRect(
        x: zr.origin.x * srcW,
        y: (1 - zr.origin.y - zr.height) * srcH,
        width: zr.width * srcW,
        height: zr.height * srcH
      )
      image = image.cropped(to: cropRect)
    }

    let ext = image.extent
    let scaleX = videoRect.width / ext.width
    let scaleY = videoRect.height / ext.height
    image = image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    let shifted = image.extent
    image = image.transformed(
      by: CGAffineTransform(
        translationX: videoRect.origin.x - shifted.origin.x,
        y: videoRect.origin.y - shifted.origin.y
      )
    )

    if instruction.videoCornerRadius > 0 {
      image = hdrApplyRoundedRectMask(to: image, rect: videoRect, cornerRadius: instruction.videoCornerRadius)
    }

    return image
  }

  // MARK: - Rounded Rect Mask

  static func hdrApplyRoundedRectMask(to image: CIImage, rect: CGRect, cornerRadius: CGFloat) -> CIImage {
    let w = Int(ceil(rect.width))
    let h = Int(ceil(rect.height))
    guard w > 0, h > 0 else { return image }
    guard
      let maskCtx = CGContext(
        data: nil,
        width: w,
        height: h,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGImageAlphaInfo.none.rawValue
      )
    else { return image }

    maskCtx.setFillColor(gray: 0, alpha: 1)
    maskCtx.fill([CGRect(origin: .zero, size: CGSize(width: w, height: h))])
    maskCtx.setFillColor(gray: 1, alpha: 1)
    let path = CGPath(
      roundedRect: CGRect(origin: .zero, size: CGSize(width: w, height: h)),
      cornerWidth: cornerRadius,
      cornerHeight: cornerRadius,
      transform: nil
    )
    maskCtx.addPath(path)
    maskCtx.fillPath()

    guard let maskCG = maskCtx.makeImage() else { return image }
    let mask = CIImage(cgImage: maskCG)
      .transformed(by: CGAffineTransform(translationX: rect.origin.x, y: rect.origin.y))

    return image.applyingFilter(
      "CIBlendWithMask",
      parameters: [
        kCIInputBackgroundImageKey: CIImage.empty(),
        kCIInputMaskImageKey: mask,
      ]
    )
  }

  // MARK: - Shadow

  private static func hdrShadow(rect: CGRect, cornerRadius: CGFloat, shadow: CGFloat) -> CIImage {
    let blur = shadowBlur(rect: rect, shadow: shadow)
    let solid = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0.6)).cropped(to: rect)
    let masked: CIImage
    if cornerRadius > 0 {
      masked = hdrApplyRoundedRectMask(to: solid, rect: rect, cornerRadius: cornerRadius)
    } else {
      masked = solid
    }
    return masked.applyingGaussianBlur(sigma: Double(blur))
      .cropped(to: rect.insetBy(dx: -blur * 3, dy: -blur * 3))
  }

  // MARK: - Transitions

  static func hdrApplyTransition(
    to image: CIImage,
    type: RegionTransitionType,
    progress: CGFloat,
    canvasSize: CGSize
  ) -> CIImage {
    switch type {
    case .none:
      return image
    case .fade:
      return image.applyingFilter(
        "CIColorMatrix",
        parameters: [
          "inputAVector": CIVector(x: 0, y: 0, z: 0, w: progress)
        ]
      )
    case .scale:
      let cx = canvasSize.width / 2
      let cy = canvasSize.height / 2
      return
        image
        .transformed(by: CGAffineTransform(translationX: -cx, y: -cy))
        .transformed(by: CGAffineTransform(scaleX: progress, y: progress))
        .transformed(by: CGAffineTransform(translationX: cx, y: cy))
    case .slide:
      let offsetY = (1.0 - progress) * canvasSize.height
      return image.transformed(by: CGAffineTransform(translationX: 0, y: -offsetY))
    }
  }

  // MARK: - Webcam Compositing

  private static func hdrComposeWebcam(
    webcamImage: CIImage,
    over background: CIImage,
    instruction: CompositionInstruction,
    compositionTime: CMTime,
    outputWidth: Int,
    outputHeight: Int,
    isCamFullscreen: Bool,
    regionTransition: (type: RegionTransitionType, progress: CGFloat)?
  ) -> CIImage {
    var result = background

    if isCamFullscreen {
      let fullRect = CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight)
      let webcamSize = webcamImage.extent.size
      let drawRect: CGRect
      if instruction.cameraFullscreenAspect == .original {
        drawRect = AVMakeRect(aspectRatio: webcamSize, insideRect: fullRect)
      } else {
        let targetAspect = instruction.cameraFullscreenAspect.aspectRatio(webcamSize: webcamSize)
        let virtualSize = CGSize(width: targetAspect * 1000, height: 1000)
        drawRect = AVMakeRect(aspectRatio: virtualSize, insideRect: fullRect)
      }

      if regionTransition == nil || regionTransition!.type == .none {
        result = hdrBackground(rect: fullRect, instruction: instruction)
      }

      var webcamLayer = hdrFitWebcam(
        webcamImage,
        in: drawRect,
        fillMode: instruction.cameraFullscreenFillMode
      )
      if instruction.cameraMirrored {
        webcamLayer = hdrMirror(webcamLayer, centerX: drawRect.midX)
      }

      if let rt = regionTransition, rt.type != .none {
        webcamLayer = hdrApplyTransition(
          to: webcamLayer,
          type: rt.type,
          progress: rt.progress,
          canvasSize: fullRect.size
        )
      }

      result = webcamLayer.composited(over: result)
    } else if let cam = resolveCamera(
      instruction: instruction,
      compositionTime: compositionTime,
      outputWidth: outputWidth,
      outputHeight: outputHeight
    ) {
      let flippedY = CGFloat(outputHeight) - cam.rect.origin.y - cam.rect.height
      let drawRect = CGRect(x: cam.rect.origin.x, y: flippedY, width: cam.rect.width, height: cam.rect.height)
      let canvasSize = CGSize(width: outputWidth, height: outputHeight)

      if cam.shadow > 0 {
        let shadow = hdrShadow(rect: drawRect, cornerRadius: cam.cornerRadius, shadow: cam.shadow)
        result = shadow.composited(over: result)
      }

      if cam.borderWidth > 0 {
        let borderLayer = CIImage(color: CIColor(cgColor: cam.borderColor)).cropped(to: drawRect)
        let maskedBorder = hdrApplyRoundedRectMask(to: borderLayer, rect: drawRect, cornerRadius: cam.cornerRadius)
        result = maskedBorder.composited(over: result)

        let insetRect = drawRect.insetBy(dx: cam.borderWidth, dy: cam.borderWidth)
        let innerRadius = max(0, cam.cornerRadius - cam.borderWidth)
        var inner = hdrFillWebcam(webcamImage, in: insetRect)
        if cam.mirrored { inner = hdrMirror(inner, centerX: insetRect.midX) }
        inner = hdrApplyRoundedRectMask(to: inner, rect: insetRect, cornerRadius: innerRadius)

        if let rt = regionTransition, rt.type != .none {
          inner = hdrApplyTransition(to: inner, type: rt.type, progress: rt.progress, canvasSize: canvasSize)
        }

        result = inner.composited(over: result)
      } else {
        var layer = hdrFillWebcam(webcamImage, in: drawRect)
        if cam.mirrored { layer = hdrMirror(layer, centerX: drawRect.midX) }
        layer = hdrApplyRoundedRectMask(to: layer, rect: drawRect, cornerRadius: cam.cornerRadius)

        if let rt = regionTransition, rt.type != .none {
          layer = hdrApplyTransition(to: layer, type: rt.type, progress: rt.progress, canvasSize: canvasSize)
        }

        result = layer.composited(over: result)
      }
    }

    return result
  }

  private static func hdrFillWebcam(_ image: CIImage, in rect: CGRect) -> CIImage {
    let imgSize = image.extent.size
    let fillRect = aspectFillRect(imageSize: imgSize, in: rect)
    let scaleX = fillRect.width / image.extent.width
    let scaleY = fillRect.height / image.extent.height
    return
      image
      .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
      .transformed(
        by: CGAffineTransform(
          translationX: fillRect.origin.x - image.extent.origin.x * scaleX,
          y: fillRect.origin.y - image.extent.origin.y * scaleY
        )
      )
      .cropped(to: rect)
  }

  private static func hdrFitWebcam(
    _ image: CIImage,
    in rect: CGRect,
    fillMode: CameraFullscreenFillMode
  ) -> CIImage {
    let imgSize = image.extent.size
    let targetRect: CGRect
    switch fillMode {
    case .fit:
      targetRect = AVMakeRect(aspectRatio: imgSize, insideRect: rect)
    case .fill:
      targetRect = aspectFillRect(imageSize: imgSize, in: rect)
    }
    let scaleX = targetRect.width / image.extent.width
    let scaleY = targetRect.height / image.extent.height
    return
      image
      .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
      .transformed(
        by: CGAffineTransform(
          translationX: targetRect.origin.x - image.extent.origin.x * scaleX,
          y: targetRect.origin.y - image.extent.origin.y * scaleY
        )
      )
      .cropped(to: rect)
  }

  private static func hdrMirror(_ image: CIImage, centerX: CGFloat) -> CIImage {
    image
      .transformed(by: CGAffineTransform(translationX: -centerX, y: 0))
      .transformed(by: CGAffineTransform(scaleX: -1, y: 1))
      .transformed(by: CGAffineTransform(translationX: centerX, y: 0))
  }

  // MARK: - SDR Overlays

  private static func hdrRenderScreenOverlays(
    over background: CIImage,
    screenBuffer: CVPixelBuffer,
    videoRect: CGRect,
    instruction: CompositionInstruction,
    compositionTime: CMTime,
    outputWidth: Int,
    outputHeight: Int
  ) -> CIImage {
    let metadataTime = CMTimeGetSeconds(compositionTime) + instruction.trimStartSeconds
    let compositionSeconds = CMTimeGetSeconds(compositionTime)

    let hasCursor = instruction.showCursor && instruction.cursorSnapshot != nil
    let hasSpotlight = instruction.isSpotlightActive(at: compositionSeconds) && instruction.cursorSnapshot != nil

    guard hasCursor || hasSpotlight else { return background }

    guard
      let ctx = CGContext(
        data: nil,
        width: outputWidth,
        height: outputHeight,
        bitsPerComponent: 8,
        bytesPerRow: outputWidth * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
      )
    else { return background }

    ctx.clear(CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))

    let zoomRect = resolveZoomRect(compositionTime: compositionTime, instruction: instruction)

    let screenWidth = CVPixelBufferGetWidth(screenBuffer)
    let screenHeight = CVPixelBufferGetHeight(screenBuffer)

    if hasSpotlight {
      drawSpotlightOverlay(
        in: ctx,
        videoRect: videoRect,
        instruction: instruction,
        compositionSeconds: compositionSeconds,
        metadataTime: metadataTime,
        zoomRect: zoomRect,
        outputHeight: outputHeight
      )
    }

    if hasCursor {
      var screenCGImage: CGImage?
      VTCreateCGImageFromCVPixelBuffer(screenBuffer, options: nil, imageOut: &screenCGImage)
      if let screenCGImage {
        drawCursorOverlay(
          in: ctx,
          screenImage: screenCGImage,
          videoRect: videoRect,
          instruction: instruction,
          metadataTime: metadataTime,
          zoomRect: zoomRect,
          outputHeight: outputHeight
        )
      } else {
        let fakeSize = CGSize(width: screenWidth, height: screenHeight)
        let drawScale = videoRect.width / max(fakeSize.width, 1)
        ctx.saveGState()
        ctx.translateBy(x: 0, y: CGFloat(outputHeight))
        ctx.scaleBy(x: 1, y: -1)
        let flippedVideoRect = CGRect(
          x: videoRect.origin.x,
          y: CGFloat(outputHeight) - videoRect.origin.y - videoRect.height,
          width: videoRect.width,
          height: videoRect.height
        )
        if let snapshot = instruction.cursorSnapshot {
          let cursorPos = snapshot.sample(at: metadataTime)
          var pixelX: CGFloat
          var pixelY: CGFloat
          if let zr = zoomRect, zr.width < 1.0 || zr.height < 1.0 {
            pixelX =
              flippedVideoRect.origin.x + ((cursorPos.x - zr.origin.x) / zr.width) * flippedVideoRect.width
            pixelY =
              flippedVideoRect.origin.y + ((cursorPos.y - zr.origin.y) / zr.height) * flippedVideoRect.height
          } else {
            pixelX = flippedVideoRect.origin.x + cursorPos.x * flippedVideoRect.width
            pixelY = flippedVideoRect.origin.y + cursorPos.y * flippedVideoRect.height
          }
          let zoomScale: CGFloat = (zoomRect != nil && zoomRect!.width < 1.0) ? 1.0 / zoomRect!.width : 1.0
          CursorRenderer.drawCursor(
            in: ctx,
            position: CGPoint(x: pixelX, y: pixelY),
            style: instruction.cursorStyle,
            size: instruction.cursorSize * drawScale * zoomScale,
            fillColor: instruction.cursorFillColor,
            strokeColor: instruction.cursorStrokeColor
          )
        }
        ctx.restoreGState()
      }
    }

    guard let overlayImage = ctx.makeImage() else { return background }
    let overlay = CIImage(cgImage: overlayImage)
    return overlay.composited(over: background)
  }

  private static func hdrRenderCaptions(
    over background: CIImage,
    videoRect: CGRect,
    instruction: CompositionInstruction,
    compositionTime: CMTime,
    outputWidth: Int,
    outputHeight: Int
  ) -> CIImage {
    guard instruction.captionsEnabled, !instruction.captionSegments.isEmpty else { return background }

    guard
      let ctx = CGContext(
        data: nil,
        width: outputWidth,
        height: outputHeight,
        bitsPerComponent: 8,
        bytesPerRow: outputWidth * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
      )
    else { return background }

    ctx.clear(CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
    let canvasRect = CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight)
    drawCaptions(in: ctx, videoRect: videoRect, canvasRect: canvasRect, instruction: instruction, compositionTime: compositionTime)

    guard let overlayImage = ctx.makeImage() else { return background }
    let overlay = CIImage(cgImage: overlayImage)
    return overlay.composited(over: background)
  }
}
