import AVFoundation
import CoreVideo

final class CameraVideoCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
  private let segmentationProcessor = PersonSegmentationProcessor(quality: .balanced)

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

    var processedWebcamImage: CGImage?
    if let wb = webcamBuffer, instruction.cameraBackgroundStyle != .none {
      CVPixelBufferLockBaseAddress(wb, .readOnly)
      processedWebcamImage = segmentationProcessor.processFrame(
        webcamBuffer: wb,
        style: instruction.cameraBackgroundStyle,
        backgroundCGImage: instruction.cameraBackgroundImage
      )
      CVPixelBufferUnlockBaseAddress(wb, .readOnly)
    }

    CameraVideoCompositor.renderFrame(
      screenBuffer: screenBuffer,
      webcamBuffer: webcamBuffer,
      outputBuffer: outputBuffer,
      compositionTime: request.compositionTime,
      instruction: instruction,
      processedWebcamImage: processedWebcamImage
    )

    request.finish(withComposedVideoFrame: outputBuffer)
  }

  static func renderFrame(
    screenBuffer: CVPixelBuffer,
    webcamBuffer: CVPixelBuffer?,
    outputBuffer: CVPixelBuffer,
    compositionTime: CMTime,
    instruction: CompositionInstruction,
    processedWebcamImage: CGImage? = nil
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

    let screenTransition: (type: RegionTransitionType, progress: CGFloat)? = {
      guard !instruction.videoRegions.isEmpty else { return nil }
      guard let region = instruction.videoRegions.first(where: { $0.timeRange.containsTime(compositionTime) }) else {
        return nil
      }
      let p = computeRegionTransition(compositionTime: compositionTime, region: region)
      let t = resolveActiveTransitionType(compositionTime: compositionTime, region: region)
      guard t != .none else { return nil }
      return (t, p)
    }()

    if let st = screenTransition {
      context.saveGState()
      switch st.type {
      case .none:
        break
      case .fade:
        context.setAlpha(st.progress)
      case .scale:
        let cx = CGFloat(width) / 2
        let cy = CGFloat(height) / 2
        context.translateBy(x: cx, y: cy)
        context.scaleBy(x: st.progress, y: st.progress)
        context.translateBy(x: -cx, y: -cy)
      case .slide:
        let offsetY = (1.0 - st.progress) * CGFloat(height)
        context.translateBy(x: 0, y: -offsetY)
      }
    }

    let screenImage = createImage(from: screenBuffer, colorSpace: colorSpace)
    if let img = screenImage {
      let screenAspect = CGSize(width: img.width, height: img.height)
      let videoRect = AVMakeRect(aspectRatio: screenAspect, insideRect: paddedArea)

      drawScreenVideo(
        in: context,
        screenImage: img,
        videoRect: videoRect,
        instruction: instruction,
        compositionTime: compositionTime,
        outputHeight: height
      )
    }

    if screenTransition != nil {
      context.restoreGState()
    }

    if let webcamBuffer {
      let hiddenRegion = instruction.cameraHiddenRegions.first {
        $0.timeRange.containsTime(compositionTime)
      }

      let hiddenTransition: (type: RegionTransitionType, progress: CGFloat)? = {
        guard let r = hiddenRegion else { return nil }
        let p = computeRegionTransition(compositionTime: compositionTime, region: r)
        return (resolveActiveTransitionType(compositionTime: compositionTime, region: r), 1.0 - p)
      }()

      if hiddenRegion != nil && (hiddenTransition == nil || hiddenTransition!.type == .none) {
        return
      }

      let fsRegion = instruction.cameraFullscreenRegions.first {
        $0.timeRange.containsTime(compositionTime)
      }
      let isCamFullscreen = hiddenRegion == nil && fsRegion != nil

      let regionTransition: (type: RegionTransitionType, progress: CGFloat)? = {
        if let ht = hiddenTransition, ht.type != .none { return ht }
        if let r = fsRegion {
          let p = computeRegionTransition(compositionTime: compositionTime, region: r)
          let t = resolveActiveTransitionType(compositionTime: compositionTime, region: r)
          if t != .none { return (t, p) }
        }
        if let r = instruction.cameraCustomRegions.first(where: { $0.timeRange.containsTime(compositionTime) }) {
          let info = RegionTransitionInfo(
            timeRange: r.timeRange,
            entryTransition: r.entryTransition,
            entryDuration: r.entryDuration,
            exitTransition: r.exitTransition,
            exitDuration: r.exitDuration
          )
          let p = computeRegionTransition(compositionTime: compositionTime, region: info)
          let t = resolveActiveTransitionType(compositionTime: compositionTime, region: info)
          if t != .none { return (t, p) }
        }
        return nil
      }()

      let webcamImage = processedWebcamImage ?? createImage(from: webcamBuffer, colorSpace: colorSpace)

      if let webcamImage {
        drawWebcam(
          in: context,
          webcamImage: webcamImage,
          instruction: instruction,
          compositionTime: compositionTime,
          outputWidth: width,
          outputHeight: height,
          isCamFullscreen: isCamFullscreen,
          regionTransition: regionTransition,
          colorSpace: colorSpace
        )
      }
    }
  }

  static func computeRegionTransition(
    compositionTime: CMTime,
    region: RegionTransitionInfo
  ) -> CGFloat {
    let t = CMTimeGetSeconds(compositionTime)
    let start = CMTimeGetSeconds(region.timeRange.start)
    let end = CMTimeGetSeconds(region.timeRange.end)
    let elapsed = t - start
    let remaining = end - t
    if region.entryTransition != .none && elapsed < region.entryDuration {
      return smoothstep(elapsed / region.entryDuration)
    }
    if region.exitTransition != .none && remaining < region.exitDuration {
      return smoothstep(remaining / region.exitDuration)
    }
    return 1.0
  }

  static func resolveActiveTransitionType(
    compositionTime: CMTime,
    region: RegionTransitionInfo
  ) -> RegionTransitionType {
    let t = CMTimeGetSeconds(compositionTime)
    let start = CMTimeGetSeconds(region.timeRange.start)
    let end = CMTimeGetSeconds(region.timeRange.end)
    let elapsed = t - start
    let remaining = end - t
    if region.entryTransition != .none && elapsed < region.entryDuration {
      return region.entryTransition
    }
    if region.exitTransition != .none && remaining < region.exitDuration {
      return region.exitTransition
    }
    return .none
  }

  struct ResolvedCamera {
    let rect: CGRect
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let borderColor: CGColor
    let shadow: CGFloat
    let mirrored: Bool
  }

  static func resolveCamera(
    instruction: CompositionInstruction,
    compositionTime: CMTime,
    outputWidth: Int,
    outputHeight: Int
  ) -> ResolvedCamera? {
    let canvasSize = instruction.canvasSize
    let scaleX = CGFloat(outputWidth) / canvasSize.width
    let scaleY = CGFloat(outputHeight) / canvasSize.height
    let scale = min(scaleX, scaleY)

    if let region = instruction.cameraCustomRegions.first(where: { $0.timeRange.containsTime(compositionTime) }),
      let ws = instruction.webcamSize
    {
      let pixelRect = region.layout.pixelRect(screenSize: canvasSize, webcamSize: ws, cameraAspect: region.cameraAspect)
      let scaledRect = CGRect(
        x: pixelRect.origin.x * scaleX,
        y: pixelRect.origin.y * scaleY,
        width: pixelRect.width * scaleX,
        height: pixelRect.height * scaleY
      )
      let minDim = min(scaledRect.width, scaledRect.height)
      return ResolvedCamera(
        rect: scaledRect,
        cornerRadius: minDim * (region.cornerRadius / 100.0),
        borderWidth: region.borderWidth * scale,
        borderColor: region.borderColor,
        shadow: region.shadow,
        mirrored: region.mirrored
      )
    }

    guard let rect = instruction.cameraRect else { return nil }
    return ResolvedCamera(
      rect: rect,
      cornerRadius: instruction.cameraCornerRadius,
      borderWidth: instruction.cameraBorderWidth,
      borderColor: instruction.cameraBorderColor,
      shadow: instruction.cameraShadow,
      mirrored: instruction.cameraMirrored
    )
  }

  static func aspectFillRect(imageSize: CGSize, in rect: CGRect) -> CGRect {
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

  static func createImage(from pixelBuffer: CVPixelBuffer, colorSpace: CGColorSpace) -> CGImage? {
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
