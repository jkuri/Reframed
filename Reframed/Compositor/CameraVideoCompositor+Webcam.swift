import AVFoundation
import CoreVideo

extension CameraVideoCompositor {
  static func drawWebcam(
    in context: CGContext,
    webcamImage: CGImage,
    instruction: CompositionInstruction,
    compositionTime: CMTime,
    outputWidth: Int,
    outputHeight: Int,
    isCamFullscreen: Bool,
    regionTransition: (type: RegionTransitionType, progress: CGFloat)?,
    colorSpace: CGColorSpace
  ) {
    let isFullscreenScale = isCamFullscreen && regionTransition?.type == .scale && regionTransition!.progress < 1.0

    if isFullscreenScale,
      let pipCam = resolveCamera(
        instruction: instruction,
        compositionTime: compositionTime,
        outputWidth: outputWidth,
        outputHeight: outputHeight
      )
    {
      drawFullscreenScaleTransition(
        in: context,
        webcamImage: webcamImage,
        instruction: instruction,
        pipCam: pipCam,
        progress: regionTransition!.progress,
        outputWidth: outputWidth,
        outputHeight: outputHeight
      )
      return
    }

    if let rt = regionTransition, rt.type != .none {
      context.saveGState()
      applyWebcamTransition(
        in: context,
        transition: rt,
        instruction: instruction,
        compositionTime: compositionTime,
        outputWidth: outputWidth,
        outputHeight: outputHeight
      )
    }

    if isCamFullscreen {
      drawFullscreenWebcam(
        in: context,
        webcamImage: webcamImage,
        instruction: instruction,
        regionTransition: regionTransition,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
        colorSpace: colorSpace
      )
    } else if let cam = resolveCamera(
      instruction: instruction,
      compositionTime: compositionTime,
      outputWidth: outputWidth,
      outputHeight: outputHeight
    ) {
      drawPiPWebcam(
        in: context,
        webcamImage: webcamImage,
        cam: cam,
        outputHeight: outputHeight
      )
    }

    if regionTransition != nil && regionTransition!.type != .none {
      context.restoreGState()
    }
  }

  private static func drawFullscreenScaleTransition(
    in context: CGContext,
    webcamImage: CGImage,
    instruction: CompositionInstruction,
    pipCam: ResolvedCamera,
    progress: CGFloat,
    outputWidth: Int,
    outputHeight: Int
  ) {
    let p = progress
    let canvasRect = CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight)
    let webcamSize = CGSize(width: webcamImage.width, height: webcamImage.height)
    let fullRect: CGRect
    if instruction.cameraFullscreenAspect == .original {
      fullRect = canvasRect
    } else {
      let targetAspect = instruction.cameraFullscreenAspect.aspectRatio(webcamSize: webcamSize)
      let virtualSize = CGSize(width: targetAspect * 1000, height: 1000)
      let vAspect = virtualSize.width / max(virtualSize.height, 1)
      let rectAspect = canvasRect.width / max(canvasRect.height, 1)
      if vAspect > rectAspect {
        let h = canvasRect.width / max(vAspect, 0.001)
        fullRect = CGRect(
          x: canvasRect.origin.x,
          y: canvasRect.midY - h / 2,
          width: canvasRect.width,
          height: h
        )
      } else {
        let w = canvasRect.height * vAspect
        fullRect = CGRect(
          x: canvasRect.midX - w / 2,
          y: canvasRect.origin.y,
          width: w,
          height: canvasRect.height
        )
      }
    }
    let pipFlippedY = CGFloat(outputHeight) - pipCam.rect.origin.y - pipCam.rect.height
    let pipRect = CGRect(x: pipCam.rect.origin.x, y: pipFlippedY, width: pipCam.rect.width, height: pipCam.rect.height)

    let interpRect = CGRect(
      x: pipRect.origin.x + (fullRect.origin.x - pipRect.origin.x) * p,
      y: pipRect.origin.y + (fullRect.origin.y - pipRect.origin.y) * p,
      width: pipRect.width + (fullRect.width - pipRect.width) * p,
      height: pipRect.height + (fullRect.height - pipRect.height) * p
    )
    let interpRadius = pipCam.cornerRadius * (1.0 - p)
    let interpBorder = pipCam.borderWidth * (1.0 - p)

    if interpBorder > 0 {
      let borderPath = CGPath(
        roundedRect: interpRect,
        cornerWidth: interpRadius,
        cornerHeight: interpRadius,
        transform: nil
      )
      context.saveGState()
      context.addPath(borderPath)
      context.setFillColor(pipCam.borderColor)
      context.fillPath()
      context.restoreGState()

      let insetRect = interpRect.insetBy(dx: interpBorder, dy: interpBorder)
      let innerRadius = max(0, interpRadius - interpBorder)
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
        roundedRect: interpRect,
        cornerWidth: interpRadius,
        cornerHeight: interpRadius,
        transform: nil
      )
      context.saveGState()
      context.addPath(path)
      context.clip()
      if instruction.cameraMirrored {
        context.translateBy(x: interpRect.midX, y: 0)
        context.scaleBy(x: -1, y: 1)
        context.translateBy(x: -interpRect.midX, y: 0)
      }
      let fillRect = aspectFillRect(imageSize: CGSize(width: webcamImage.width, height: webcamImage.height), in: interpRect)
      context.draw(webcamImage, in: fillRect)
      context.restoreGState()
    }
  }

  private static func applyWebcamTransition(
    in context: CGContext,
    transition: (type: RegionTransitionType, progress: CGFloat),
    instruction: CompositionInstruction,
    compositionTime: CMTime,
    outputWidth: Int,
    outputHeight: Int
  ) {
    switch transition.type {
    case .none:
      break
    case .fade:
      context.setAlpha(transition.progress)
    case .scale:
      let scaleCam = resolveCamera(
        instruction: instruction,
        compositionTime: compositionTime,
        outputWidth: outputWidth,
        outputHeight: outputHeight
      )
      let cx: CGFloat
      let cy: CGFloat
      if let cam = scaleCam {
        let flippedY = CGFloat(outputHeight) - cam.rect.origin.y - cam.rect.height
        cx = cam.rect.origin.x + cam.rect.width / 2
        cy = flippedY + cam.rect.height / 2
      } else {
        cx = CGFloat(outputWidth) / 2
        cy = CGFloat(outputHeight) / 2
      }
      context.translateBy(x: cx, y: cy)
      context.scaleBy(x: transition.progress, y: transition.progress)
      context.translateBy(x: -cx, y: -cy)
    case .slide:
      let slideCam = resolveCamera(
        instruction: instruction,
        compositionTime: compositionTime,
        outputWidth: outputWidth,
        outputHeight: outputHeight
      )
      let slideDistance: CGFloat
      if let cam = slideCam {
        let flippedY = CGFloat(outputHeight) - cam.rect.origin.y - cam.rect.height
        slideDistance = flippedY + cam.rect.height
      } else {
        slideDistance = CGFloat(outputHeight)
      }
      let offsetY = (1.0 - transition.progress) * slideDistance
      context.translateBy(x: 0, y: -offsetY)
    }
  }

  private static func drawFullscreenWebcam(
    in context: CGContext,
    webcamImage: CGImage,
    instruction: CompositionInstruction,
    regionTransition: (type: RegionTransitionType, progress: CGFloat)?,
    outputWidth: Int,
    outputHeight: Int,
    colorSpace: CGColorSpace
  ) {
    let fullRect = CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight)
    let targetAspect = instruction.cameraFullscreenAspect.aspectRatio(
      webcamSize: CGSize(width: webcamImage.width, height: webcamImage.height)
    )
    let virtualSize: CGSize
    if instruction.cameraFullscreenAspect == .original {
      virtualSize = CGSize(width: webcamImage.width, height: webcamImage.height)
    } else {
      virtualSize = CGSize(width: targetAspect * 1000, height: 1000)
    }
    let drawRect = AVMakeRect(aspectRatio: virtualSize, insideRect: fullRect)
    context.saveGState()
    if regionTransition == nil || regionTransition!.type == .none {
      drawBackground(in: context, rect: fullRect, instruction: instruction, colorSpace: colorSpace)
    }
    context.clip(to: fullRect)
    if instruction.cameraMirrored {
      context.translateBy(x: drawRect.midX, y: 0)
      context.scaleBy(x: -1, y: 1)
      context.translateBy(x: -drawRect.midX, y: 0)
    }
    let webcamSize = CGSize(width: webcamImage.width, height: webcamImage.height)
    if instruction.cameraFullscreenAspect == .original {
      context.draw(webcamImage, in: drawRect)
    } else {
      context.clip(to: drawRect)
      let imgRect: CGRect
      switch instruction.cameraFullscreenFillMode {
      case .fit:
        imgRect = AVMakeRect(aspectRatio: webcamSize, insideRect: drawRect)
      case .fill:
        imgRect = aspectFillRect(imageSize: webcamSize, in: drawRect)
      }
      context.draw(webcamImage, in: imgRect)
    }
    context.restoreGState()
  }

  private static func drawPiPWebcam(
    in context: CGContext,
    webcamImage: CGImage,
    cam: ResolvedCamera,
    outputHeight: Int
  ) {
    let flippedY = CGFloat(outputHeight) - cam.rect.origin.y - cam.rect.height
    let drawRect = CGRect(
      x: cam.rect.origin.x,
      y: flippedY,
      width: cam.rect.width,
      height: cam.rect.height
    )

    if cam.shadow > 0 {
      let blur = min(drawRect.width, drawRect.height) * cam.shadow / 2000.0
      context.saveGState()
      context.setShadow(
        offset: .zero,
        blur: blur,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.6)
      )
      let shadowPath = CGPath(
        roundedRect: drawRect,
        cornerWidth: cam.cornerRadius,
        cornerHeight: cam.cornerRadius,
        transform: nil
      )
      context.addPath(shadowPath)
      context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
      context.fillPath()
      context.restoreGState()
    }

    if cam.borderWidth > 0 {
      let borderPath = CGPath(
        roundedRect: drawRect,
        cornerWidth: cam.cornerRadius,
        cornerHeight: cam.cornerRadius,
        transform: nil
      )
      context.saveGState()
      context.addPath(borderPath)
      context.setFillColor(cam.borderColor)
      context.fillPath()
      context.restoreGState()

      let insetRect = drawRect.insetBy(dx: cam.borderWidth, dy: cam.borderWidth)
      let innerRadius = max(0, cam.cornerRadius - cam.borderWidth)
      let innerPath = CGPath(
        roundedRect: insetRect,
        cornerWidth: innerRadius,
        cornerHeight: innerRadius,
        transform: nil
      )
      context.saveGState()
      context.addPath(innerPath)
      context.clip()
      if cam.mirrored {
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
        cornerWidth: cam.cornerRadius,
        cornerHeight: cam.cornerRadius,
        transform: nil
      )
      context.saveGState()
      context.addPath(path)
      context.clip()
      if cam.mirrored {
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
