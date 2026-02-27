import AVFoundation
import AppKit

extension VideoPreviewContainer {
  func layoutAll() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)

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

    screenContainerLayer.bounds = CGRect(origin: .zero, size: screenRect.size)
    screenContainerLayer.position = CGPoint(x: screenRect.midX, y: screenRect.midY)
    let cornerRadius = min(screenRect.width, screenRect.height) * (currentVideoCornerRadius / 100.0)
    let maskPath = CGPath(
      roundedRect: CGRect(origin: .zero, size: screenRect.size),
      cornerWidth: cornerRadius,
      cornerHeight: cornerRadius,
      transform: nil
    )
    screenMaskLayer.frame = CGRect(origin: .zero, size: screenRect.size)
    screenMaskLayer.path = maskPath
    screenContainerLayer.mask = screenMaskLayer

    if currentVideoShadow > 0 {
      let blur = min(screenRect.width, screenRect.height) * currentVideoShadow / 2000.0
      screenShadowLayer.frame = screenRect
      screenShadowLayer.shadowPath = CGPath(
        roundedRect: CGRect(origin: .zero, size: screenRect.size),
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
      )
      screenShadowLayer.shadowRadius = blur
      screenShadowLayer.shadowOpacity = 0.6
      screenShadowLayer.isHidden = false
    } else {
      screenShadowLayer.isHidden = true
      screenShadowLayer.shadowOpacity = 0
    }

    let zr = currentZoomRect
    if zr.width < 1.0 || zr.height < 1.0 {
      let cw = screenRect.width
      let ch = screenRect.height
      let pw = cw / zr.width
      let ph = ch / zr.height
      let px = -zr.origin.x * pw
      let py = -(1 - zr.origin.y - zr.height) * ph
      screenPlayerLayer.frame = CGRect(x: px, y: py, width: pw, height: ph)
    } else {
      screenPlayerLayer.frame = screenContainerLayer.bounds
    }

    if isScreenHidden && screenTransitionType == .none {
      screenContainerLayer.opacity = 0
      screenShadowLayer.opacity = 0
    } else if screenTransitionType != .none {
      let p = Float(screenTransitionProgress)
      switch screenTransitionType {
      case .none:
        screenContainerLayer.opacity = 1
        screenContainerLayer.transform = CATransform3DIdentity
        screenShadowLayer.opacity = currentVideoShadow > 0 ? 0.6 : 0
      case .fade:
        screenContainerLayer.opacity = p
        screenContainerLayer.transform = CATransform3DIdentity
        screenShadowLayer.opacity = currentVideoShadow > 0 ? p * 0.6 : 0
      case .scale:
        screenContainerLayer.opacity = 1
        screenContainerLayer.transform = CATransform3DMakeScale(CGFloat(p), CGFloat(p), 1)
        screenShadowLayer.opacity = currentVideoShadow > 0 ? p * 0.6 : 0
      case .slide:
        screenContainerLayer.opacity = 1
        let offsetY = (1.0 - CGFloat(p)) * (screenRect.origin.y + screenRect.height)
        screenContainerLayer.transform = CATransform3DMakeTranslation(0, -offsetY, 0)
        screenShadowLayer.opacity = currentVideoShadow > 0 ? p * 0.6 : 0
      }
    } else {
      screenContainerLayer.opacity = 1
      screenContainerLayer.transform = CATransform3DIdentity
      screenShadowLayer.opacity = currentVideoShadow > 0 ? 0.6 : 0
    }

    guard let ws = currentWebcamSize, webcamPlayerLayer.player != nil else {
      webcamWrapper.isHidden = true
      CATransaction.commit()
      return
    }

    if isDraggingCamera {
      CATransaction.commit()
      return
    }

    let hasActiveTransition = cameraTransitionType != .none && cameraTransitionProgress < 1.0
    if isCameraHidden && !hasActiveTransition {
      webcamWrapper.isHidden = true
      webcamWrapper.alphaValue = 1.0
      webcamWrapper.layer?.transform = CATransform3DIdentity
      screenContainerLayer.isHidden = false
      cursorOverlay.isHidden = false
      CATransaction.commit()
      return
    }

    webcamWrapper.isHidden = false

    if isCameraHidden && hasActiveTransition {
      webcamWrapper.alphaValue = 1.0
      webcamWrapper.layer?.transform = CATransform3DIdentity
      screenContainerLayer.isHidden = false
      cursorOverlay.isHidden = false
    }

    if isCameraFullscreen {
      let isScaleTransition = cameraTransitionType == .scale && cameraTransitionProgress < 1.0

      if isScaleTransition {
        screenContainerLayer.isHidden = false
        cursorOverlay.isHidden = false
        webcamWrapper.layer?.shadowOpacity = 0
        webcamView.layer?.backgroundColor = NSColor.clear.cgColor

        let camAspect = currentCameraAspect.heightToWidthRatio(webcamSize: ws)
        let pipW = canvasRect.width * currentLayout.relativeWidth
        let pipH = pipW * camAspect
        let pipX = canvasRect.origin.x + canvasRect.width * currentLayout.relativeX
        let pipY = canvasRect.origin.y + canvasRect.height * currentLayout.relativeY
        let pipFrame = CGRect(x: pipX, y: bounds.height - pipY - pipH, width: pipW, height: pipH)

        let fsTargetRect: CGRect
        if currentFullscreenAspect == .original {
          fsTargetRect = canvasRect
        } else {
          let targetAspect = currentFullscreenAspect.aspectRatio(webcamSize: ws)
          let virtualSize = CGSize(width: targetAspect * 1000, height: 1000)
          let fsContainer = CGRect(origin: .zero, size: canvasRect.size)
          let innerRect: CGRect
          if currentFullscreenFillMode == .fill {
            let rectAspect = fsContainer.width / max(fsContainer.height, 1)
            let vAspect = virtualSize.width / max(virtualSize.height, 1)
            if vAspect > rectAspect {
              let h = fsContainer.width / max(vAspect, 0.001)
              innerRect = CGRect(x: 0, y: fsContainer.midY - h / 2, width: fsContainer.width, height: h)
            } else {
              let w = fsContainer.height * vAspect
              innerRect = CGRect(x: fsContainer.midX - w / 2, y: 0, width: w, height: fsContainer.height)
            }
          } else {
            innerRect = AVMakeRect(aspectRatio: virtualSize, insideRect: fsContainer)
          }
          fsTargetRect = CGRect(
            x: canvasRect.origin.x + innerRect.origin.x,
            y: canvasRect.origin.y + innerRect.origin.y,
            width: innerRect.width,
            height: innerRect.height
          )
        }

        let p = cameraTransitionProgress
        let interpFrame = CGRect(
          x: pipFrame.origin.x + (fsTargetRect.origin.x - pipFrame.origin.x) * p,
          y: pipFrame.origin.y + (fsTargetRect.origin.y - pipFrame.origin.y) * p,
          width: pipFrame.width + (fsTargetRect.width - pipFrame.width) * p,
          height: pipFrame.height + (fsTargetRect.height - pipFrame.height) * p
        )

        let pipMinDim = min(pipW, pipH)
        let pipRadius = pipMinDim * (currentCameraCornerRadius / 100.0)
        let interpRadius = pipRadius * (1.0 - p)
        let pipBorder = currentCameraBorderWidth * min(scaleX, scaleY)
        let interpBorder = pipBorder * (1.0 - p)

        webcamWrapper.frame = interpFrame
        webcamView.frame = webcamWrapper.bounds
        webcamView.layer?.cornerRadius = interpRadius
        webcamView.layer?.borderWidth = interpBorder
        webcamView.layer?.borderColor = interpBorder > 0 ? currentCameraBorderColor : NSColor.clear.cgColor

        webcamPlayerLayer.videoGravity = .resizeAspectFill
        webcamPlayerLayer.setAffineTransform(.identity)
        webcamPlayerLayer.frame = webcamView.bounds
        webcamPlayerLayer.setAffineTransform(
          currentCameraMirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity
        )

        syncProcessedWebcamLayer()
        webcamWrapper.alphaValue = 1.0
        webcamWrapper.layer?.transform = CATransform3DIdentity
        CATransaction.commit()
        return
      }

      webcamWrapper.layer?.shadowOpacity = 0
      let fsTransitioning = hasActiveTransition
      screenContainerLayer.isHidden = !fsTransitioning
      cursorOverlay.isHidden = !fsTransitioning
      webcamWrapper.frame = canvasRect
      webcamView.frame = webcamWrapper.bounds
      webcamView.layer?.cornerRadius = 0
      webcamView.layer?.borderWidth = 0
      webcamView.layer?.borderColor = NSColor.clear.cgColor
      webcamView.layer?.backgroundColor = NSColor.clear.cgColor

      webcamPlayerLayer.setAffineTransform(.identity)
      let gravity: AVLayerVideoGravity =
        currentFullscreenFillMode == .fill
        ? .resizeAspectFill : .resizeAspect
      webcamPlayerLayer.videoGravity = gravity

      let containerBounds = webcamView.bounds
      if currentFullscreenAspect == .original {
        webcamPlayerLayer.frame = containerBounds
      } else {
        let targetAspect = currentFullscreenAspect.aspectRatio(webcamSize: ws)
        let virtualSize = CGSize(width: targetAspect * 1000, height: 1000)
        let aspectRect: CGRect
        if currentFullscreenFillMode == .fill {
          let rectAspect = containerBounds.width / max(containerBounds.height, 1)
          let vAspect = virtualSize.width / max(virtualSize.height, 1)
          if vAspect > rectAspect {
            let h = containerBounds.width / max(vAspect, 0.001)
            aspectRect = CGRect(
              x: 0,
              y: containerBounds.midY - h / 2,
              width: containerBounds.width,
              height: h
            )
          } else {
            let w = containerBounds.height * vAspect
            aspectRect = CGRect(
              x: containerBounds.midX - w / 2,
              y: 0,
              width: w,
              height: containerBounds.height
            )
          }
        } else {
          aspectRect = AVMakeRect(aspectRatio: virtualSize, insideRect: containerBounds)
        }
        webcamPlayerLayer.frame = aspectRect
      }

      webcamPlayerLayer.setAffineTransform(
        currentCameraMirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity
      )
      syncProcessedWebcamLayer()
      applyTransitionEffect()
      CATransaction.commit()
      return
    }

    screenContainerLayer.isHidden = false
    cursorOverlay.isHidden = false
    webcamView.layer?.backgroundColor = NSColor.clear.cgColor

    let camAspect = currentCameraAspect.heightToWidthRatio(webcamSize: ws)
    let w = canvasRect.width * currentLayout.relativeWidth
    let h = w * camAspect
    let x = canvasRect.origin.x + canvasRect.width * currentLayout.relativeX
    let y = canvasRect.origin.y + canvasRect.height * currentLayout.relativeY

    let minDim = min(w, h)
    let scaledRadius = minDim * (currentCameraCornerRadius / 100.0)
    let scaledBorder = currentCameraBorderWidth * min(scaleX, scaleY)

    let webcamFrame = CGRect(x: x, y: bounds.height - y - h, width: w, height: h)
    webcamWrapper.frame = webcamFrame
    webcamView.frame = webcamWrapper.bounds
    webcamView.layer?.cornerRadius = scaledRadius
    webcamView.layer?.borderWidth = scaledBorder
    webcamView.layer?.borderColor =
      scaledBorder > 0
      ? currentCameraBorderColor
      : NSColor.clear.cgColor
    webcamPlayerLayer.videoGravity = .resizeAspectFill
    webcamPlayerLayer.setAffineTransform(.identity)
    webcamPlayerLayer.frame = webcamView.bounds
    webcamPlayerLayer.setAffineTransform(
      currentCameraMirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity
    )

    if currentCameraShadow > 0 {
      let camBlur = minDim * currentCameraShadow / 2000.0
      webcamWrapper.layer?.shadowColor = NSColor.black.cgColor
      webcamWrapper.layer?.shadowOffset = .zero
      webcamWrapper.layer?.shadowRadius = camBlur
      webcamWrapper.layer?.shadowOpacity = 0.6
      webcamWrapper.layer?.shadowPath = CGPath(
        roundedRect: webcamView.bounds,
        cornerWidth: scaledRadius,
        cornerHeight: scaledRadius,
        transform: nil
      )
    } else {
      webcamWrapper.layer?.shadowOpacity = 0
    }

    syncProcessedWebcamLayer()
    applyTransitionEffect()
    CATransaction.commit()
  }

  func syncProcessedWebcamLayer() {
    if currentCameraBackgroundStyle != .none {
      processedWebcamLayer.frame = webcamPlayerLayer.frame
      if isCameraFullscreen {
        processedWebcamLayer.contentsGravity =
          currentFullscreenFillMode == .fill ? .resizeAspectFill : .resizeAspect
      } else {
        processedWebcamLayer.contentsGravity = .resizeAspectFill
      }
      if currentCameraMirrored {
        processedWebcamLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
      } else {
        processedWebcamLayer.setAffineTransform(.identity)
      }
    }
  }

  func applyTransitionEffect() {
    guard cameraTransitionType != .none else {
      webcamWrapper.alphaValue = 1.0
      webcamWrapper.layer?.transform = CATransform3DIdentity
      return
    }
    let p = cameraTransitionProgress
    switch cameraTransitionType {
    case .none:
      webcamWrapper.alphaValue = 1.0
      webcamWrapper.layer?.transform = CATransform3DIdentity
    case .fade:
      webcamWrapper.alphaValue = p
      webcamWrapper.layer?.transform = CATransform3DIdentity
    case .scale:
      webcamWrapper.alphaValue = 1.0
      let cx = webcamWrapper.bounds.width / 2
      let cy = webcamWrapper.bounds.height / 2
      var transform = CATransform3DIdentity
      transform = CATransform3DTranslate(transform, cx, cy, 0)
      transform = CATransform3DScale(transform, p, p, 1)
      transform = CATransform3DTranslate(transform, -cx, -cy, 0)
      webcamWrapper.layer?.transform = transform
    case .slide:
      webcamWrapper.alphaValue = 1.0
      let distanceToBottom = webcamWrapper.frame.origin.y + webcamWrapper.frame.height
      let offsetY = (1.0 - p) * distanceToBottom
      webcamWrapper.layer?.transform = CATransform3DMakeTranslation(0, -offsetY, 0)
    }
  }

  func updateZoomRect(_ rect: CGRect) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    currentZoomRect = rect
    let containerBounds = screenContainerLayer.bounds
    if rect.width >= 1.0 && rect.height >= 1.0 {
      screenPlayerLayer.frame = containerBounds
    } else {
      let cw = containerBounds.width
      let ch = containerBounds.height
      let pw = cw / rect.width
      let ph = ch / rect.height
      let px = -rect.origin.x * pw
      let py = -(1 - rect.origin.y - rect.height) * ph
      screenPlayerLayer.frame = CGRect(x: px, y: py, width: pw, height: ph)
    }
    CATransaction.commit()
  }

  func updateCameraLayout(
    _ layout: CameraLayout,
    webcamSize: CGSize?,
    screenSize: CGSize,
    canvasSize: CGSize,
    padding: CGFloat = 0,
    videoCornerRadius: CGFloat = 0,
    cameraAspect: CameraAspect = .original,
    cameraCornerRadius: CGFloat = 12,
    cameraBorderWidth: CGFloat = 0,
    cameraBorderColor: CGColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.3),
    videoShadow: CGFloat = 0,
    cameraShadow: CGFloat = 0,
    cameraMirrored: Bool = false
  ) {
    currentLayout = layout
    currentWebcamSize = webcamSize
    currentScreenSize = screenSize
    currentCanvasSize = canvasSize.width > 0 ? canvasSize : screenSize
    currentPadding = padding
    currentVideoCornerRadius = videoCornerRadius
    currentCameraAspect = cameraAspect
    currentCameraCornerRadius = cameraCornerRadius
    currentCameraBorderWidth = cameraBorderWidth
    currentCameraBorderColor = cameraBorderColor
    currentVideoShadow = videoShadow
    currentCameraShadow = cameraShadow
    currentCameraMirrored = cameraMirrored
    layoutAll()
  }
}
