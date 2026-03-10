import AVFoundation
import CoreVideo
import VideoToolbox

final class FrameRenderer: NSObject, AVVideoCompositing, @unchecked Sendable {
  private let segmentationProcessor = PersonSegmentationProcessor(quality: .balanced)

  private static let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
  private static let deviceRGBColorSpace = CGColorSpaceCreateDeviceRGB()

  private static let halfFloatBitmapInfo: UInt32 =
    CGBitmapInfo.floatComponents.rawValue
    | CGBitmapInfo.byteOrder16Little.rawValue
    | CGImageAlphaInfo.premultipliedLast.rawValue

  private static let bgraBitmapInfo: UInt32 =
    CGBitmapInfo.byteOrder32Little.rawValue
    | CGImageAlphaInfo.premultipliedFirst.rawValue

  var sourcePixelBufferAttributes: [String: any Sendable]? {
    [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_64RGBAHalf]
  }

  var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] {
    [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_64RGBAHalf]
  }

  var supportsHDRSourceFrames: Bool { true }

  var supportsWideColorSourceFrames: Bool { true }

  func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

  func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
    guard let instruction = request.videoCompositionInstruction as? CompositionInstruction else {
      request.finish(with: NSError(domain: "FrameRenderer", code: -1))
      return
    }

    guard let screenBuffer = request.sourceFrame(byTrackID: instruction.screenTrackID) else {
      request.finish(with: NSError(domain: "FrameRenderer", code: -2))
      return
    }

    guard let outputBuffer = request.renderContext.newPixelBuffer() else {
      request.finish(with: NSError(domain: "FrameRenderer", code: -3))
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

    Self.renderFrame(
      screenBuffer: screenBuffer,
      webcamBuffer: webcamBuffer,
      outputBuffer: outputBuffer,
      compositionTime: request.compositionTime,
      instruction: instruction,
      processedWebcamImage: processedWebcamImage
    )

    request.finish(withComposedVideoFrame: outputBuffer)
  }

  static func computeFrameState(
    screenBuffer: CVPixelBuffer,
    webcamBuffer: CVPixelBuffer?,
    outputBuffer: CVPixelBuffer,
    compositionTime: CMTime,
    instruction: CompositionInstruction
  ) -> FrameState {
    let width = CVPixelBufferGetWidth(outputBuffer)
    let height = CVPixelBufferGetHeight(outputBuffer)
    let canvasRect = CGRect(x: 0, y: 0, width: width, height: height)

    let paddedArea = CGRect(
      x: instruction.paddingH,
      y: instruction.paddingV,
      width: CGFloat(width) - 2 * instruction.paddingH,
      height: CGFloat(height) - 2 * instruction.paddingV
    )

    let screenAspect = CGSize(
      width: CVPixelBufferGetWidth(screenBuffer),
      height: CVPixelBufferGetHeight(screenBuffer)
    )
    let videoRect = AVMakeRect(aspectRatio: screenAspect, insideRect: paddedArea)

    let isCamFullscreen: Bool = {
      let hidden = instruction.cameraHiddenRegions.contains { $0.timeRange.containsTime(compositionTime) }
      let fs = instruction.cameraFullscreenRegions.contains { $0.timeRange.containsTime(compositionTime) }
      return !hidden && fs
    }()

    let camFsTransitioning: Bool = {
      guard isCamFullscreen else { return false }
      guard
        let r = instruction.cameraFullscreenRegions.first(where: { $0.timeRange.containsTime(compositionTime) })
      else { return false }
      return resolveActiveTransitionType(compositionTime: compositionTime, region: r) != .none
    }()

    let screenTransition: TransitionState? = {
      guard !instruction.videoRegions.isEmpty else { return nil }
      guard let region = instruction.videoRegions.first(where: { $0.timeRange.containsTime(compositionTime) }) else {
        return nil
      }
      let p = computeRegionTransition(compositionTime: compositionTime, region: region)
      let t = resolveActiveTransitionType(compositionTime: compositionTime, region: region)
      guard t != .none else { return nil }
      return TransitionState(type: t, progress: p)
    }()

    let isScreenTransitioning = screenTransition != nil || (isCamFullscreen && !camFsTransitioning)

    var webcamFullyHidden = false
    var webcamRegionTransition: TransitionState?

    if webcamBuffer != nil {
      let hiddenRegion = instruction.cameraHiddenRegions.first {
        $0.timeRange.containsTime(compositionTime)
      }

      let hiddenTransition: TransitionState? = {
        guard let r = hiddenRegion else { return nil }
        let p = computeRegionTransition(compositionTime: compositionTime, region: r)
        let t = resolveActiveTransitionType(compositionTime: compositionTime, region: r)
        return TransitionState(type: t, progress: 1.0 - p)
      }()

      if hiddenRegion != nil && (hiddenTransition == nil || hiddenTransition!.type == .none) {
        webcamFullyHidden = true
      } else {
        if let ht = hiddenTransition, ht.type != .none {
          webcamRegionTransition = ht
        } else {
          let fsRegion = instruction.cameraFullscreenRegions.first {
            $0.timeRange.containsTime(compositionTime)
          }
          if let r = fsRegion {
            let p = computeRegionTransition(compositionTime: compositionTime, region: r)
            let t = resolveActiveTransitionType(compositionTime: compositionTime, region: r)
            if t != .none { webcamRegionTransition = TransitionState(type: t, progress: p) }
          }
          if webcamRegionTransition == nil,
            let r = instruction.cameraCustomRegions.first(where: { $0.timeRange.containsTime(compositionTime) })
          {
            let info = RegionTransitionInfo(
              timeRange: r.timeRange,
              entryTransition: r.entryTransition,
              entryDuration: r.entryDuration,
              exitTransition: r.exitTransition,
              exitDuration: r.exitDuration
            )
            let p = computeRegionTransition(compositionTime: compositionTime, region: info)
            let t = resolveActiveTransitionType(compositionTime: compositionTime, region: info)
            if t != .none { webcamRegionTransition = TransitionState(type: t, progress: p) }
          }
        }
      }
    }

    return FrameState(
      width: width,
      height: height,
      canvasRect: canvasRect,
      paddedArea: paddedArea,
      videoRect: videoRect,
      isCamFullscreen: isCamFullscreen,
      screenTransition: screenTransition,
      isScreenTransitioning: isScreenTransitioning,
      webcamFullyHidden: webcamFullyHidden,
      webcamRegionTransition: webcamRegionTransition
    )
  }

  static func renderFrame(
    screenBuffer: CVPixelBuffer,
    webcamBuffer: CVPixelBuffer?,
    outputBuffer: CVPixelBuffer,
    compositionTime: CMTime,
    instruction: CompositionInstruction,
    processedWebcamImage: CGImage? = nil
  ) {
    let state = computeFrameState(
      screenBuffer: screenBuffer,
      webcamBuffer: webcamBuffer,
      outputBuffer: outputBuffer,
      compositionTime: compositionTime,
      instruction: instruction
    )

    if instruction.isHDR {
      renderFrameHDR(
        screenBuffer: screenBuffer,
        webcamBuffer: webcamBuffer,
        outputBuffer: outputBuffer,
        compositionTime: compositionTime,
        instruction: instruction,
        processedWebcamImage: processedWebcamImage,
        state: state
      )
      return
    }

    let is16bit = CVPixelBufferGetPixelFormatType(outputBuffer) == kCVPixelFormatType_64RGBAHalf
    let colorSpace = is16bit ? Self.sRGBColorSpace : Self.deviceRGBColorSpace
    let bitsPerComponent = is16bit ? 16 : 8
    let bitmapInfo = is16bit ? Self.halfFloatBitmapInfo : Self.bgraBitmapInfo

    CVPixelBufferLockBaseAddress(screenBuffer, .readOnly)
    CVPixelBufferLockBaseAddress(outputBuffer, [])
    if let wb = webcamBuffer {
      CVPixelBufferLockBaseAddress(wb, .readOnly)
    }

    defer {
      CVPixelBufferUnlockBaseAddress(screenBuffer, .readOnly)
      CVPixelBufferUnlockBaseAddress(outputBuffer, [])
      if let wb = webcamBuffer {
        CVPixelBufferUnlockBaseAddress(wb, .readOnly)
      }
    }

    guard
      let context = makeBitmapContext(
        for: outputBuffer,
        colorSpace: colorSpace,
        bitsPerComponent: bitsPerComponent,
        bitmapInfo: bitmapInfo
      )
    else {
      return
    }

    context.interpolationQuality = .high

    drawBackground(in: context, rect: state.canvasRect, instruction: instruction, colorSpace: colorSpace)

    if let st = state.screenTransition {
      context.saveGState()
      switch st.type {
      case .none:
        break
      case .fade:
        context.setAlpha(st.progress)
      case .scale:
        let cx = CGFloat(state.width) / 2
        let cy = CGFloat(state.height) / 2
        context.translateBy(x: cx, y: cy)
        context.scaleBy(x: st.progress, y: st.progress)
        context.translateBy(x: -cx, y: -cy)
      case .slide:
        let offsetY = (1.0 - st.progress) * CGFloat(state.height)
        context.translateBy(x: 0, y: -offsetY)
      }
    }

    let screenImage = createImage(from: screenBuffer)
    if let img = screenImage {
      drawScreenVideo(
        in: context,
        screenImage: img,
        videoRect: state.videoRect,
        instruction: instruction,
        compositionTime: compositionTime,
        outputHeight: state.height,
        isTransitioning: state.isScreenTransitioning
      )
    }

    if state.screenTransition != nil {
      context.restoreGState()
    }

    if let webcamBuffer {
      if state.webcamFullyHidden {
        drawCaptions(
          in: context,
          videoRect: state.videoRect,
          canvasRect: state.canvasRect,
          instruction: instruction,
          compositionTime: compositionTime
        )
        return
      }

      let webcamImage = processedWebcamImage ?? createImage(from: webcamBuffer)

      if let webcamImage {
        let regionTransition: (type: RegionTransitionType, progress: CGFloat)? =
          state.webcamRegionTransition.map { ($0.type, $0.progress) }
        drawWebcam(
          in: context,
          webcamImage: webcamImage,
          instruction: instruction,
          compositionTime: compositionTime,
          outputWidth: state.width,
          outputHeight: state.height,
          isCamFullscreen: state.isCamFullscreen,
          regionTransition: regionTransition,
          colorSpace: colorSpace
        )
      }
    }

    if let screenImage {
      let screenAspect = CGSize(width: screenImage.width, height: screenImage.height)
      let vRect = AVMakeRect(aspectRatio: screenAspect, insideRect: state.paddedArea)
      drawCaptions(
        in: context,
        videoRect: vRect,
        canvasRect: state.canvasRect,
        instruction: instruction,
        compositionTime: compositionTime
      )
    }
  }
}
