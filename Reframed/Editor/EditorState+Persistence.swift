import AVFoundation
import AppKit
import CoreMedia
import Foundation

extension EditorState {
  func scheduleSave() {
    pendingSaveTask?.cancel()
    pendingSaveTask = Task {
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled else { return }
      saveState()
    }
  }

  func createSnapshot() -> EditorStateData {
    var cursorSettings: CursorSettingsData?
    if cursorMetadataProvider != nil {
      cursorSettings = CursorSettingsData(
        showCursor: showCursor,
        cursorStyleRaw: cursorStyle.rawValue,
        cursorSize: cursorSize,
        cursorFillColor: cursorFillColor,
        cursorStrokeColor: cursorStrokeColor,
        showClickHighlights: showClickHighlights,
        clickHighlightColor: clickHighlightColor,
        clickHighlightSize: clickHighlightSize,
        spotlightEnabled: spotlightEnabled,
        spotlightRadius: spotlightRadius,
        spotlightDimOpacity: spotlightDimOpacity,
        spotlightEdgeSoftness: spotlightEdgeSoftness,
        clickSoundEnabled: clickSoundEnabled,
        clickSoundVolume: clickSoundVolume,
        clickSoundStyleRaw: clickSoundStyle.rawValue
      )
    }
    var zoomSettings: ZoomSettingsData?
    if cursorMetadataProvider != nil {
      zoomSettings = ZoomSettingsData(
        zoomEnabled: zoomEnabled,
        autoZoomEnabled: autoZoomEnabled,
        zoomFollowCursor: zoomFollowCursor,
        zoomLevel: zoomLevel,
        transitionDuration: zoomTransitionSpeed,
        dwellThreshold: zoomDwellThreshold,
        keyframes: zoomTimeline?.allKeyframes ?? []
      )
    }
    var animationSettings: AnimationSettingsData?
    if cursorMetadataProvider != nil {
      animationSettings = AnimationSettingsData(
        cursorMovementEnabled: cursorMovementEnabled,
        cursorMovementSpeed: cursorMovementSpeed,
        useSystemCursor: useSystemCursor,
        cursorSway: cursorSway,
        cursorMotionBlur: cursorMotionBlur,
        clickBounce: clickBounce
      )
    }
    var audioSettings: AudioSettingsData?
    if hasSystemAudio || hasMicAudio {
      var cachedIntensity: Float?
      if micNoiseReductionEnabled,
        let proj = project,
        proj.denoisedMicAudioURL != nil
      {
        cachedIntensity = micNoiseReductionIntensity
      }
      audioSettings = AudioSettingsData(
        systemAudioVolume: systemAudioVolume,
        micAudioVolume: micAudioVolume,
        systemAudioMuted: systemAudioMuted,
        micAudioMuted: micAudioMuted,
        micNoiseReductionEnabled: micNoiseReductionEnabled,
        micNoiseReductionIntensity: micNoiseReductionIntensity,
        cachedNoiseReductionIntensity: cachedIntensity
      )
    }
    var captionSettings: CaptionSettingsData?
    if !captionSegments.isEmpty {
      captionSettings = CaptionSettingsData(
        enabled: captionsEnabled,
        fontSize: captionFontSize,
        fontWeight: captionFontWeight,
        textColor: captionTextColor,
        backgroundColor: captionBackgroundColor,
        backgroundOpacity: captionBackgroundOpacity,
        showBackground: captionShowBackground,
        position: captionPosition,
        maxWordsPerLine: captionMaxWordsPerLine,
        model: captionModel,
        language: captionLanguage,
        audioSource: captionAudioSource
      )
    }
    return EditorStateData(
      trimStartSeconds: CMTimeGetSeconds(trimStart),
      trimEndSeconds: CMTimeGetSeconds(trimEnd),
      backgroundStyle: backgroundStyle,
      backgroundImageFillMode: backgroundImageFillMode,
      canvasAspect: canvasAspect,
      padding: padding,
      videoCornerRadius: videoCornerRadius,
      cameraAspect: cameraAspect,
      cameraCornerRadius: cameraCornerRadius,
      cameraBorderWidth: cameraBorderWidth,
      cameraBorderColor: cameraBorderColor,
      videoShadow: videoShadow,
      cameraShadow: cameraShadow,
      cameraMirrored: cameraMirrored,
      cameraFullscreenFillMode: cameraFullscreenFillMode,
      cameraFullscreenAspect: cameraFullscreenAspect,
      cameraLayout: cameraLayout,
      webcamEnabled: webcamEnabled,
      cursorSettings: cursorSettings,
      zoomSettings: zoomSettings,
      animationSettings: animationSettings,
      audioSettings: audioSettings,
      systemAudioRegions: systemAudioRegions.isEmpty ? nil : systemAudioRegions,
      micAudioRegions: micAudioRegions.isEmpty ? nil : micAudioRegions,
      cameraRegions: cameraRegions.isEmpty ? nil : cameraRegions,
      videoRegions: videoRegions.isEmpty ? nil : videoRegions,
      cameraBackgroundStyle: cameraBackgroundStyle == .none ? nil : cameraBackgroundStyle,
      captionSettings: captionSettings,
      captionSegments: captionSegments.isEmpty ? nil : captionSegments,
      spotlightRegions: spotlightRegions.isEmpty ? nil : spotlightRegions
    )
  }

  func restoreFromSnapshot(_ data: EditorStateData) {
    isRestoringState = true
    pendingUndoTask?.cancel()

    let prev = createSnapshot()

    trimStart = .zero
    trimEnd = playerController.duration
    playerController.trimEnd = playerController.duration

    backgroundStyle = data.backgroundStyle
    backgroundImageFillMode = data.backgroundImageFillMode ?? .fill
    canvasAspect = data.canvasAspect ?? .original
    padding = data.padding
    videoCornerRadius = data.videoCornerRadius
    cameraAspect = data.cameraAspect ?? .original
    cameraCornerRadius = data.cameraCornerRadius
    cameraBorderWidth = data.cameraBorderWidth
    cameraBorderColor = data.cameraBorderColor ?? CodableColor(r: 0, g: 0, b: 0, a: 1)
    videoShadow = data.videoShadow ?? 0
    cameraShadow = data.cameraShadow ?? 0
    cameraMirrored = data.cameraMirrored ?? false
    cameraFullscreenFillMode = data.cameraFullscreenFillMode ?? .fit
    cameraFullscreenAspect = data.cameraFullscreenAspect ?? .original
    cameraLayout = data.cameraLayout
    webcamEnabled = data.webcamEnabled ?? true

    if let cursorSettings = data.cursorSettings {
      showCursor = cursorSettings.showCursor
      cursorStyle = CursorStyle(rawValue: cursorSettings.cursorStyleRaw) ?? .centerDefault
      cursorSize = cursorSettings.cursorSize
      cursorFillColor = cursorSettings.cursorFillColor ?? CodableColor(r: 1, g: 1, b: 1)
      cursorStrokeColor = cursorSettings.cursorStrokeColor ?? CodableColor(r: 0, g: 0, b: 0)
      showClickHighlights = cursorSettings.showClickHighlights
      if let savedColor = cursorSettings.clickHighlightColor {
        clickHighlightColor = savedColor
      }
      clickHighlightSize = cursorSettings.clickHighlightSize
      spotlightEnabled = cursorSettings.spotlightEnabled
      spotlightRadius = cursorSettings.spotlightRadius
      spotlightDimOpacity = cursorSettings.spotlightDimOpacity
      spotlightEdgeSoftness = cursorSettings.spotlightEdgeSoftness
      clickSoundEnabled = cursorSettings.clickSoundEnabled
      clickSoundVolume = cursorSettings.clickSoundVolume
      clickSoundStyle = ClickSoundStyle(rawValue: cursorSettings.clickSoundStyleRaw) ?? .click001
    }

    if let zoomSettings = data.zoomSettings {
      zoomEnabled = zoomSettings.zoomEnabled
      autoZoomEnabled = zoomSettings.autoZoomEnabled
      zoomFollowCursor = zoomSettings.zoomFollowCursor
      zoomLevel = zoomSettings.zoomLevel
      zoomTransitionSpeed = zoomSettings.transitionDuration
      zoomDwellThreshold = zoomSettings.dwellThreshold
      if !zoomSettings.keyframes.isEmpty {
        zoomTimeline = ZoomTimeline(keyframes: zoomSettings.keyframes)
      } else {
        zoomTimeline = nil
      }
    }

    if let animSettings = data.animationSettings {
      cursorMovementEnabled = animSettings.cursorMovementEnabled
      cursorMovementSpeed = animSettings.cursorMovementSpeed
      useSystemCursor = animSettings.useSystemCursor
      cursorSway = animSettings.cursorSway
      cursorMotionBlur = animSettings.cursorMotionBlur
      clickBounce = animSettings.clickBounce
    }

    if let savedSysRegions = data.systemAudioRegions, !savedSysRegions.isEmpty {
      systemAudioRegions = savedSysRegions
    }
    if let savedMicRegions = data.micAudioRegions, !savedMicRegions.isEmpty {
      micAudioRegions = savedMicRegions
    }
    if let savedCameraRegions = data.cameraRegions, !savedCameraRegions.isEmpty {
      cameraRegions = savedCameraRegions
    } else if let legacyRegions = data.cameraFullscreenRegions, !legacyRegions.isEmpty {
      cameraRegions = legacyRegions.map {
        CameraRegionData(id: $0.id, startSeconds: $0.startSeconds, endSeconds: $0.endSeconds, type: .fullscreen)
      }
    }
    if let savedVideoRegions = data.videoRegions, !savedVideoRegions.isEmpty {
      videoRegions = savedVideoRegions
    } else {
      let dur = CMTimeGetSeconds(duration)
      videoRegions = [VideoRegionData(startSeconds: 0, endSeconds: dur)]
    }
    if let audioSettings = data.audioSettings {
      systemAudioVolume = audioSettings.systemAudioVolume
      micAudioVolume = audioSettings.micAudioVolume
      systemAudioMuted = audioSettings.systemAudioMuted
      micAudioMuted = audioSettings.micAudioMuted
      micNoiseReductionEnabled = audioSettings.micNoiseReductionEnabled
      micNoiseReductionIntensity = audioSettings.micNoiseReductionIntensity
    }

    if let captionSettings = data.captionSettings {
      captionsEnabled = captionSettings.enabled
      captionFontSize = captionSettings.fontSize
      captionFontWeight = captionSettings.fontWeight
      captionTextColor = captionSettings.textColor
      captionBackgroundColor = captionSettings.backgroundColor
      captionBackgroundOpacity = captionSettings.backgroundOpacity
      captionShowBackground = captionSettings.showBackground
      captionPosition = captionSettings.position
      captionMaxWordsPerLine = captionSettings.maxWordsPerLine
      captionModel = captionSettings.model
      captionLanguage = captionSettings.language
      captionAudioSource = captionSettings.audioSource
    }
    if let savedSegments = data.captionSegments, !savedSegments.isEmpty {
      captionSegments = savedSegments
    } else {
      captionSegments = []
    }

    if let savedSpotlightRegions = data.spotlightRegions, !savedSpotlightRegions.isEmpty {
      spotlightRegions = savedSpotlightRegions
    } else if spotlightEnabled && data.spotlightRegions == nil {
      let dur = CMTimeGetSeconds(duration)
      spotlightRegions = [SpotlightRegionData(startSeconds: 0, endSeconds: dur)]
    } else {
      spotlightRegions = []
    }

    if case .image(let filename) = data.backgroundStyle, let bundleURL = project?.bundleURL {
      let url = bundleURL.appendingPathComponent(filename)
      backgroundImage = NSImage(contentsOf: url)
    }

    cameraBackgroundStyle = data.cameraBackgroundStyle ?? CameraBackgroundStyle.none
    if case .image(let filename) = data.cameraBackgroundStyle, let bundleURL = project?.bundleURL {
      let url = bundleURL.appendingPathComponent(filename)
      if let image = NSImage(contentsOf: url) {
        cameraBackgroundImage = image
      } else {
        cameraBackgroundStyle = .none
        cameraBackgroundImage = nil
      }
    } else if data.cameraBackgroundStyle == nil || data.cameraBackgroundStyle == CameraBackgroundStyle.none {
      cameraBackgroundImage = nil
    }

    let volumeChanged =
      prev.audioSettings?.systemAudioVolume != data.audioSettings?.systemAudioVolume
      || prev.audioSettings?.micAudioVolume != data.audioSettings?.micAudioVolume
      || prev.audioSettings?.systemAudioMuted != data.audioSettings?.systemAudioMuted
      || prev.audioSettings?.micAudioMuted != data.audioSettings?.micAudioMuted
    if volumeChanged {
      syncAudioVolumes()
    }

    let regionsChanged =
      prev.systemAudioRegions != data.systemAudioRegions
      || prev.micAudioRegions != data.micAudioRegions
    if regionsChanged {
      syncAudioRegionsToPlayer()
    }

    let noiseChanged =
      prev.audioSettings?.micNoiseReductionEnabled
      != data.audioSettings?.micNoiseReductionEnabled
      || prev.audioSettings?.micNoiseReductionIntensity
        != data.audioSettings?.micNoiseReductionIntensity
    if noiseChanged {
      syncNoiseReduction()
    }

    let cursorAnimChanged =
      prev.animationSettings?.cursorMovementEnabled
      != data.animationSettings?.cursorMovementEnabled
      || prev.animationSettings?.cursorMovementSpeed != data.animationSettings?.cursorMovementSpeed
    if cursorAnimChanged {
      regenerateSmoothedCursor()
    }

    let cameraChanged =
      prev.cameraLayout != data.cameraLayout
      || prev.cameraAspect != data.cameraAspect
    if cameraChanged {
      clampCameraPosition()
    }

    scheduleSave()

    Task { @MainActor [weak self] in
      self?.isRestoringState = false
    }
  }

  func undo() {
    guard let snapshot = history.undo() else { return }
    restoreFromSnapshot(snapshot)
  }

  func redo() {
    guard let snapshot = history.redo() else { return }
    restoreFromSnapshot(snapshot)
  }

  func jumpToHistory(index: Int) {
    guard let snapshot = history.jumpTo(index: index) else { return }
    restoreFromSnapshot(snapshot)
  }

  func scheduleUndoSnapshot() {
    pendingUndoTask?.cancel()
    pendingUndoTask = Task {
      try? await Task.sleep(for: .seconds(1.5))
      guard !Task.isCancelled else { return }
      history.pushSnapshot(createSnapshot())
    }
  }

  func startAutoSave() {
    observeChanges()
  }

  func observeChanges() {
    withObservationTracking {
      _ = self.backgroundStyle
      _ = self.backgroundImageFillMode
      _ = self.canvasAspect
      _ = self.padding
      _ = self.videoCornerRadius
      _ = self.cameraAspect
      _ = self.cameraCornerRadius
      _ = self.cameraBorderWidth
      _ = self.cameraBorderColor
      _ = self.videoShadow
      _ = self.cameraShadow
      _ = self.cameraMirrored
      _ = self.cameraFullscreenFillMode
      _ = self.cameraFullscreenAspect
      _ = self.cameraLayout
      _ = self.webcamEnabled
      _ = self.cameraBackgroundStyle
      _ = self.showCursor
      _ = self.cursorStyle
      _ = self.cursorSize
      _ = self.cursorFillColor
      _ = self.cursorStrokeColor
      _ = self.showClickHighlights
      _ = self.clickHighlightColor
      _ = self.clickHighlightSize
      _ = self.spotlightEnabled
      _ = self.spotlightRadius
      _ = self.spotlightDimOpacity
      _ = self.spotlightEdgeSoftness
      _ = self.spotlightRegions
      _ = self.clickSoundEnabled
      _ = self.clickSoundVolume
      _ = self.clickSoundStyle
      _ = self.zoomEnabled
      _ = self.autoZoomEnabled
      _ = self.zoomFollowCursor
      _ = self.zoomLevel
      _ = self.zoomTransitionSpeed
      _ = self.zoomDwellThreshold
      _ = self.zoomTimeline
      _ = self.cursorMovementEnabled
      _ = self.cursorMovementSpeed
      _ = self.useSystemCursor
      _ = self.cursorSway
      _ = self.cursorMotionBlur
      _ = self.clickBounce
      _ = self.trimStart
      _ = self.trimEnd
      _ = self.systemAudioRegions
      _ = self.micAudioRegions
      _ = self.cameraRegions
      _ = self.videoRegions
      _ = self.systemAudioVolume
      _ = self.micAudioVolume
      _ = self.systemAudioMuted
      _ = self.micAudioMuted
      _ = self.micNoiseReductionEnabled
      _ = self.micNoiseReductionIntensity
      _ = self.isPreviewMode
      _ = self.captionsEnabled
      _ = self.captionSegments
      _ = self.captionFontSize
      _ = self.captionFontWeight
      _ = self.captionTextColor
      _ = self.captionBackgroundColor
      _ = self.captionBackgroundOpacity
      _ = self.captionShowBackground
      _ = self.captionPosition
      _ = self.captionMaxWordsPerLine
      _ = self.captionLanguage
      _ = self.captionAudioSource
    } onChange: {
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.syncVideoRegionsToPlayer()
        self.playerController.previewMode = self.isPreviewMode
        self.scheduleSave()
        if !self.isRestoringState {
          self.scheduleUndoSnapshot()
        }
        self.observeChanges()
      }
    }
  }

  func teardown() {
    pendingSaveTask?.cancel()
    pendingUndoTask?.cancel()
    micProcessingTask?.cancel()
    micProcessingTask = nil
    transcriptionTask?.cancel()
    transcriptionTask = nil
    saveState()
    if let project {
      try? project.saveHistory(history.toData())
    }
    playerController.teardown()
    if let url = processedMicAudioURL {
      if !isURLInsideProjectBundle(url) {
        try? FileManager.default.removeItem(at: url)
      }
      processedMicAudioURL = nil
    }
  }
}
