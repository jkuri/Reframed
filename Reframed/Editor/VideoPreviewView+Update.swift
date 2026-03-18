import AVFoundation
import AppKit

extension VideoPreviewView {
  func updateCameraVisibility(_ nsView: VideoPreviewContainer) {
    let hiddenRegion = cameraHiddenRegions.first { currentTime >= $0.start && currentTime <= $0.end }
    let isCameraHidden = hiddenRegion != nil
    nsView.isCameraHidden = isCameraHidden
    let fsRegion = cameraFullscreenRegions.first { currentTime >= $0.start && currentTime <= $0.end }
    let isFullscreen = !isCameraHidden && fsRegion != nil
    nsView.isCameraFullscreen = isFullscreen
    nsView.currentFullscreenFillMode = cameraFullscreenFillMode
    nsView.currentFullscreenAspect = cameraFullscreenAspect

    let customRegion = cameraCustomRegions.first(where: { currentTime >= $0.start && currentTime <= $0.end })

    let transitionProgress: CGFloat = {
      if let r = hiddenRegion {
        let p = Self.computeTransitionProgress(
          time: currentTime,
          start: r.start,
          end: r.end,
          entryTransition: r.entryTransition,
          entryDuration: r.entryDuration,
          exitTransition: r.exitTransition,
          exitDuration: r.exitDuration
        )
        return 1.0 - p
      }
      if let r = fsRegion {
        return Self.computeTransitionProgress(
          time: currentTime,
          start: r.start,
          end: r.end,
          entryTransition: r.entryTransition,
          entryDuration: r.entryDuration,
          exitTransition: r.exitTransition,
          exitDuration: r.exitDuration
        )
      }
      if let r = customRegion {
        return Self.computeTransitionProgress(
          time: currentTime,
          start: r.start,
          end: r.end,
          entryTransition: r.entryTransition,
          entryDuration: r.entryDuration,
          exitTransition: r.exitTransition,
          exitDuration: r.exitDuration
        )
      }
      return 1.0
    }()

    let activeTransitionType: RegionTransitionType = {
      if let r = hiddenRegion {
        return Self.resolveTransitionType(
          time: currentTime,
          start: r.start,
          end: r.end,
          entryTransition: r.entryTransition,
          entryDuration: r.entryDuration,
          exitTransition: r.exitTransition,
          exitDuration: r.exitDuration
        )
      }
      if let r = fsRegion {
        return Self.resolveTransitionType(
          time: currentTime,
          start: r.start,
          end: r.end,
          entryTransition: r.entryTransition,
          entryDuration: r.entryDuration,
          exitTransition: r.exitTransition,
          exitDuration: r.exitDuration
        )
      }
      if let r = customRegion {
        return Self.resolveTransitionType(
          time: currentTime,
          start: r.start,
          end: r.end,
          entryTransition: r.entryTransition,
          entryDuration: r.entryDuration,
          exitTransition: r.exitTransition,
          exitDuration: r.exitDuration
        )
      }
      return .none
    }()

    nsView.cameraTransitionProgress = transitionProgress
    nsView.cameraTransitionType = activeTransitionType

    let isCustomTransition =
      customRegion != nil
      && hiddenRegion == nil
      && (activeTransitionType == .scale || activeTransitionType == .slide)
      && transitionProgress < 1.0
      && defaultPipLayout != nil
    nsView.isCustomRegionTransition = isCustomTransition
    if isCustomTransition {
      nsView.defaultPipLayout = defaultPipLayout!
      nsView.defaultPipCameraAspect = defaultPipCameraAspect ?? cameraAspect
      nsView.defaultPipCornerRadius = defaultPipCornerRadius ?? cameraCornerRadius
      nsView.defaultPipBorderWidth = defaultPipBorderWidth ?? cameraBorderWidth
      nsView.defaultPipBorderColor = defaultPipBorderColor ?? cameraBorderColor
      nsView.defaultPipShadow = defaultPipShadow ?? cameraShadow
      nsView.defaultPipMirrored = defaultPipMirrored ?? cameraMirrored
    }
  }

  func updateScreenVisibility(_ nsView: VideoPreviewContainer) {
    let videoRegion = videoRegions.first(where: { currentTime >= $0.start && currentTime <= $0.end })
    let screenTransitionProgress: CGFloat = {
      guard let r = videoRegion else { return 1.0 }
      return Self.computeTransitionProgress(
        time: currentTime,
        start: r.start,
        end: r.end,
        entryTransition: r.entryTransition,
        entryDuration: r.entryDuration,
        exitTransition: r.exitTransition,
        exitDuration: r.exitDuration
      )
    }()
    let screenTransitionType: RegionTransitionType = {
      guard let r = videoRegion else { return .none }
      return Self.resolveTransitionType(
        time: currentTime,
        start: r.start,
        end: r.end,
        entryTransition: r.entryTransition,
        entryDuration: r.entryDuration,
        exitTransition: r.exitTransition,
        exitDuration: r.exitDuration
      )
    }()
    nsView.screenTransitionProgress = screenTransitionProgress
    nsView.screenTransitionType = screenTransitionType
    nsView.isScreenHidden = isPreviewMode && !videoRegions.isEmpty && videoRegion == nil
  }

  func updateWebcamOutput(_ nsView: VideoPreviewContainer) {
    let prevStyle = nsView.currentCameraBackgroundStyle
    let prevImage = nsView.currentCameraBackgroundImage
    nsView.currentCameraBackgroundStyle = cameraBackgroundStyle
    nsView.currentCameraBackgroundImage = cameraBackgroundImage
    let styleChanged = prevStyle != cameraBackgroundStyle || prevImage !== cameraBackgroundImage
    if styleChanged {
      nsView.lastProcessedWebcamTime = -1
    }
    if cameraBackgroundStyle != .none, webcamPlayer != nil {
      if prevStyle == .none, let webcam = webcamPlayer {
        nsView.setupWebcamOutput(for: webcam)
      } else {
        nsView.processCurrentWebcamFrame()
      }
    } else if prevStyle != .none {
      nsView.teardownWebcamOutput()
    }
  }

  func updateLayout(_ nsView: VideoPreviewContainer) {
    let customRegion = cameraCustomRegions.first(where: { currentTime >= $0.start && currentTime <= $0.end })
    let effectiveLayout = customRegion?.layout ?? cameraLayout

    nsView.updateCameraLayout(
      effectiveLayout,
      webcamSize: webcamSize,
      screenSize: screenSize,
      canvasSize: canvasSize,
      padding: padding,
      videoCornerRadius: videoCornerRadius,
      cameraAspect: customRegion?.cameraAspect ?? cameraAspect,
      cameraCornerRadius: customRegion?.cornerRadius ?? cameraCornerRadius,
      cameraBorderWidth: customRegion?.borderWidth ?? cameraBorderWidth,
      cameraBorderColor: customRegion?.borderColor ?? cameraBorderColor,
      videoShadow: videoShadow,
      cameraShadow: customRegion?.shadow ?? cameraShadow,
      cameraMirrored: customRegion?.mirrored ?? cameraMirrored
    )
  }

  func updateZoom(_ nsView: VideoPreviewContainer) {
    if let zoom = zoomTimeline {
      var zoomRect = zoom.zoomRect(at: currentTime)
      if zoomFollowCursor, zoomRect.width < 1.0 || zoomRect.height < 1.0,
        let provider = cursorMetadataProvider
      {
        let cursorPos = provider.sample(at: currentTime)
        zoomRect = ZoomTimeline.followCursor(zoomRect, cursorPosition: cursorPos)
      }
      nsView.updateZoomRect(zoomRect)
    } else {
      nsView.updateZoomRect(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
  }

  func updateOverlays(_ nsView: VideoPreviewContainer) {
    if let provider = cursorMetadataProvider, showCursor {
      let pos = provider.sample(at: currentTime)
      let allClicks = provider.activeClicks(at: currentTime)
      let clicks = showClickHighlights ? allClicks : []

      let sampleDelta = 1.0 / 60.0
      let prevPos = provider.sample(at: max(0, currentTime - sampleDelta))
      let dx = pos.x - prevPos.x
      let dy = pos.y - prevPos.y

      let swayRotation = CursorEffects.computeSwayRotation(
        dx: dx,
        dy: dy,
        deltaSeconds: sampleDelta,
        swayIntensity: cursorSway
      )
      let bounceScale = CursorEffects.computeClickBounceScale(
        clicks: allClicks,
        clickBounce: clickBounce
      )
      let blur = CursorEffects.computeMotionBlurVelocity(
        normalizedDx: dx,
        normalizedDy: dy,
        deltaSeconds: sampleDelta,
        blurIntensity: cursorMotionBlur,
        outputSize: screenSize.width
      )

      let systemCursorType: SystemCursorType? = useSystemCursor ? provider.cursorType(at: currentTime) : nil

      nsView.updateCursorOverlay(
        normalizedPosition: pos,
        style: cursorStyle,
        size: cursorSize,
        visible: true,
        clicks: clicks,
        clickHighlightColor: clickHighlightColor,
        clickHighlightSize: clickHighlightSize,
        cursorFillColor: cursorFillColor,
        cursorStrokeColor: cursorStrokeColor,
        swayRotation: swayRotation,
        bounceScale: bounceScale,
        motionBlurDx: blur.dx,
        motionBlurDy: blur.dy,
        motionBlurMagnitude: blur.magnitude,
        systemCursorType: systemCursorType
      )

      nsView.updateSpotlightOverlay(
        normalizedPosition: pos,
        radius: spotlightRadius,
        dimOpacity: spotlightDimOpacity,
        edgeSoftness: spotlightEdgeSoftness,
        visible: spotlightEnabled
      )
    } else {
      nsView.updateCursorOverlay(
        normalizedPosition: .zero,
        style: .centerDefault,
        size: 24,
        visible: false,
        clicks: []
      )
      nsView.updateSpotlightOverlay(
        normalizedPosition: .zero,
        radius: 0,
        dimOpacity: 0,
        edgeSoftness: 0,
        visible: false
      )
    }
  }

  func updateClickSound(_ coordinator: Coordinator) {
    if clickSoundEnabled, isPlaying, let provider = cursorMetadataProvider {
      if coordinator.clickSoundPlayer == nil {
        coordinator.clickSoundPlayer = ClickSoundPlayer()
      }
      let player = coordinator.clickSoundPlayer!
      if !player.isSetup {
        player.setup()
      }
      player.updateStyle(clickSoundStyle, volume: clickSoundVolume)
      let lastTime = coordinator.lastProcessedTime
      if currentTime < lastTime - 0.1 {
        player.reset()
      }
      if lastTime >= 0, currentTime > lastTime {
        let clicks = provider.clickEvents(from: lastTime, to: currentTime)
        for click in clicks {
          player.playClick(at: click.time, button: click.button, volume: clickSoundVolume)
        }
      }
      coordinator.lastProcessedTime = currentTime
    } else {
      coordinator.clickSoundPlayer?.reset()
      coordinator.lastProcessedTime = -1
    }
  }
}
