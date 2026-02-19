import AVFoundation
import AppKit
import CoreMedia
import Foundation
import Logging

enum CanvasAspect: String, Codable, Sendable, CaseIterable, Identifiable {
  case original
  case ratio16x9
  case ratio1x1
  case ratio4x3
  case ratio9x16

  var id: String { rawValue }

  var label: String {
    switch self {
    case .original: "Original"
    case .ratio16x9: "16:9"
    case .ratio1x1: "1:1"
    case .ratio4x3: "4:3"
    case .ratio9x16: "9:16"
    }
  }

  func size(for screenSize: CGSize) -> CGSize? {
    switch self {
    case .original: nil
    case .ratio16x9: CGSize(width: screenSize.width, height: screenSize.width * 9.0 / 16.0)
    case .ratio1x1: CGSize(width: screenSize.width, height: screenSize.width)
    case .ratio4x3: CGSize(width: screenSize.width, height: screenSize.width * 3.0 / 4.0)
    case .ratio9x16: CGSize(width: screenSize.height * 9.0 / 16.0, height: screenSize.height)
    }
  }
}

enum CameraAspect: String, Codable, Sendable, CaseIterable, Identifiable {
  case original
  case ratio16x9
  case ratio1x1
  case ratio4x3
  case ratio9x16

  var id: String { rawValue }

  var label: String {
    switch self {
    case .original: "Original"
    case .ratio16x9: "16:9"
    case .ratio1x1: "1:1"
    case .ratio4x3: "4:3"
    case .ratio9x16: "9:16"
    }
  }

  func heightToWidthRatio(webcamSize: CGSize) -> CGFloat {
    switch self {
    case .original: webcamSize.height / max(webcamSize.width, 1)
    case .ratio16x9: 9.0 / 16.0
    case .ratio1x1: 1.0
    case .ratio4x3: 3.0 / 4.0
    case .ratio9x16: 16.0 / 9.0
    }
  }
}

enum CameraFullscreenFillMode: String, Codable, Sendable, CaseIterable, Identifiable {
  case fill, fit

  var id: String { rawValue }

  var label: String {
    switch self {
    case .fill: "Fill"
    case .fit: "Fit"
    }
  }
}

enum CameraFullscreenAspect: String, Codable, Sendable, CaseIterable, Identifiable {
  case original
  case ratio16x9
  case ratio1x1
  case ratio4x3
  case ratio9x16

  var id: String { rawValue }

  var label: String {
    switch self {
    case .original: "Original"
    case .ratio16x9: "16:9"
    case .ratio1x1: "1:1"
    case .ratio4x3: "4:3"
    case .ratio9x16: "9:16"
    }
  }

  func aspectRatio(webcamSize: CGSize) -> CGFloat {
    switch self {
    case .original: webcamSize.width / max(webcamSize.height, 1)
    case .ratio16x9: 16.0 / 9.0
    case .ratio1x1: 1.0
    case .ratio4x3: 4.0 / 3.0
    case .ratio9x16: 9.0 / 16.0
    }
  }
}

enum AudioTrackType {
  case system, mic
}

@MainActor
@Observable
final class EditorState {
  private(set) var result: RecordingResult
  private(set) var project: ReframedProject?
  var playerController: SyncedPlayerController
  var cameraLayout = CameraLayout()
  var trimStart: CMTime = .zero
  var trimEnd: CMTime = .zero
  var systemAudioRegions: [AudioRegionData] = []
  var micAudioRegions: [AudioRegionData] = []
  var cameraFullscreenRegions: [AudioRegionData] = []
  var isExporting = false
  var exportProgress: Double = 0
  var exportETA: Double?
  var exportTask: Task<Void, Never>?
  var exportStatusMessage: String?
  var isPreviewMode = false

  var backgroundStyle: BackgroundStyle = .solidColor(CodableColor(r: 0, g: 0, b: 0))
  var backgroundImage: NSImage?
  var backgroundImageFillMode: BackgroundImageFillMode = .fill
  var canvasAspect: CanvasAspect = .original
  var padding: CGFloat = 0
  var videoCornerRadius: CGFloat = 0
  var cameraAspect: CameraAspect = .original
  var cameraCornerRadius: CGFloat = 8
  var cameraBorderWidth: CGFloat = 0
  var cameraBorderColor: CodableColor = CodableColor(r: 0, g: 0, b: 0, a: 1)
  var videoShadow: CGFloat = 0
  var cameraShadow: CGFloat = 0
  var cameraMirrored: Bool = false
  var cameraFullscreenFillMode: CameraFullscreenFillMode = .fit
  var cameraFullscreenAspect: CameraFullscreenAspect = .original
  var projectName: String = ""
  var showExportSheet = false
  var showDeleteConfirmation = false
  var showExportResult = false
  var exportResultMessage = ""
  var exportResultIsError = false
  var lastExportedURL: URL?

  var cursorMetadataProvider: CursorMetadataProvider?
  var showCursor: Bool = true
  var cursorStyle: CursorStyle = .defaultArrow
  var cursorSize: CGFloat = 24

  var showClickHighlights: Bool = false
  var clickHighlightColor: CodableColor = CodableColor(r: 0.2, g: 0.5, b: 1.0, a: 1.0)
  var clickHighlightSize: CGFloat = 36

  var zoomTimeline: ZoomTimeline?
  var zoomEnabled: Bool = false
  var autoZoomEnabled: Bool = false
  var zoomFollowCursor: Bool = true
  var zoomLevel: Double = 2.0
  var zoomTransitionSpeed: Double = 1.0
  var zoomDwellThreshold: Double = 4.0

  var cursorMovementEnabled: Bool = false
  var cursorMovementSpeed: CursorMovementSpeed = .medium
  private(set) var smoothedCursorProvider: CursorMetadataProvider?

  var history = History()
  private var isRestoringState = false
  private var pendingUndoTask: Task<Void, Never>?

  private let logger = Logger(label: "eu.jankuri.reframed.editor-state")
  private var pendingSaveTask: Task<Void, Never>?

  var systemAudioVolume: Float = 1.0
  var micAudioVolume: Float = 1.0
  var systemAudioMuted: Bool = false
  var micAudioMuted: Bool = false
  var micNoiseReductionEnabled: Bool = false
  var micNoiseReductionIntensity: Float = 0.5

  var webcamEnabled: Bool = true

  private(set) var processedMicAudioURL: URL?
  private(set) var isMicProcessing: Bool = false
  private(set) var micProcessingProgress: Double = 0
  private var micProcessingTask: Task<Void, Never>?

  var hasSystemAudio: Bool { result.systemAudioURL != nil }
  var hasMicAudio: Bool { result.microphoneAudioURL != nil }

  var effectiveSystemAudioVolume: Float { systemAudioMuted ? 0 : systemAudioVolume }
  var effectiveMicAudioVolume: Float { micAudioMuted ? 0 : micAudioVolume }

  var isPlaying: Bool { playerController.isPlaying }
  var currentTime: CMTime { playerController.currentTime }
  var duration: CMTime { playerController.duration }
  var hasWebcam: Bool { result.webcamVideoURL != nil }

  init(project: ReframedProject) {
    self.project = project
    self.result = project.recordingResult
    self.playerController = SyncedPlayerController(result: project.recordingResult)
    self.projectName = project.name

    if let saved = project.metadata.editorState {
      self.backgroundStyle = saved.backgroundStyle
      self.canvasAspect = saved.canvasAspect ?? .original
      self.padding = saved.padding
      self.videoCornerRadius = saved.videoCornerRadius
      self.cameraAspect = saved.cameraAspect ?? .original
      self.cameraCornerRadius = saved.cameraCornerRadius
      self.cameraBorderWidth = saved.cameraBorderWidth
      self.cameraBorderColor = saved.cameraBorderColor ?? CodableColor(r: 0, g: 0, b: 0, a: 1)
      self.videoShadow = saved.videoShadow ?? 0
      self.cameraShadow = saved.cameraShadow ?? 0
      self.cameraMirrored = saved.cameraMirrored ?? false
      self.cameraFullscreenFillMode = saved.cameraFullscreenFillMode ?? .fit
      self.cameraFullscreenAspect = saved.cameraFullscreenAspect ?? .original
      self.cameraLayout = saved.cameraLayout
      self.webcamEnabled = saved.webcamEnabled ?? true
      self.backgroundImageFillMode = saved.backgroundImageFillMode ?? .fill
      if case .image(let filename) = saved.backgroundStyle {
        let url = project.bundleURL.appendingPathComponent(filename)
        self.backgroundImage = NSImage(contentsOf: url)
      }
    }
  }

  init(result: RecordingResult) {
    self.project = nil
    self.result = result
    self.playerController = SyncedPlayerController(result: result)
    self.projectName = result.screenVideoURL.deletingPathExtension().lastPathComponent
  }

  func setup() async {
    await playerController.loadDuration()
    trimEnd = playerController.duration
    let dur = CMTimeGetSeconds(playerController.duration)
    if result.systemAudioURL != nil {
      systemAudioRegions = [AudioRegionData(startSeconds: 0, endSeconds: dur)]
    }
    if result.microphoneAudioURL != nil {
      micAudioRegions = [AudioRegionData(startSeconds: 0, endSeconds: dur)]
    }
    playerController.trimEnd = trimEnd
    syncAudioRegionsToPlayer()
    playerController.setupTimeObserver()

    if let cursorURL = project?.cursorMetadataURL ?? result.cursorMetadataURL {
      cursorMetadataProvider = try? CursorMetadataProvider.load(from: cursorURL)
    }

    if let saved = project?.metadata.editorState {
      let start = CMTime(seconds: saved.trimStartSeconds, preferredTimescale: 600)
      let end = CMTime(seconds: saved.trimEndSeconds, preferredTimescale: 600)
      if CMTimeCompare(start, .zero) >= 0 && CMTimeCompare(end, start) > 0 {
        trimStart = start
        trimEnd = CMTimeMinimum(end, playerController.duration)
        playerController.trimEnd = trimEnd
      }
      if let cursorSettings = saved.cursorSettings {
        showCursor = cursorSettings.showCursor
        cursorStyle = CursorStyle(rawValue: cursorSettings.cursorStyleRaw) ?? .defaultArrow
        cursorSize = cursorSettings.cursorSize
        showClickHighlights = cursorSettings.showClickHighlights
        if let savedColor = cursorSettings.clickHighlightColor {
          clickHighlightColor = savedColor
        }
        clickHighlightSize = cursorSettings.clickHighlightSize
      }
      if let zoomSettings = saved.zoomSettings {
        zoomEnabled = zoomSettings.zoomEnabled
        autoZoomEnabled = zoomSettings.autoZoomEnabled
        zoomFollowCursor = zoomSettings.zoomFollowCursor
        zoomLevel = zoomSettings.zoomLevel
        zoomTransitionSpeed = zoomSettings.transitionDuration
        zoomDwellThreshold = zoomSettings.dwellThreshold
        if !zoomSettings.keyframes.isEmpty {
          zoomTimeline = ZoomTimeline(keyframes: zoomSettings.keyframes)
        }
      }
      if let animSettings = saved.animationSettings {
        cursorMovementEnabled = animSettings.cursorMovementEnabled
        cursorMovementSpeed = animSettings.cursorMovementSpeed
      }
      if let savedSysRegions = saved.systemAudioRegions, !savedSysRegions.isEmpty {
        systemAudioRegions = savedSysRegions
      }
      if let savedMicRegions = saved.micAudioRegions, !savedMicRegions.isEmpty {
        micAudioRegions = savedMicRegions
      }
      if let savedCameraRegions = saved.cameraFullscreenRegions, !savedCameraRegions.isEmpty {
        cameraFullscreenRegions = savedCameraRegions
      }
      if let audioSettings = saved.audioSettings {
        systemAudioVolume = audioSettings.systemAudioVolume
        micAudioVolume = audioSettings.micAudioVolume
        systemAudioMuted = audioSettings.systemAudioMuted
        micAudioMuted = audioSettings.micAudioMuted
        micNoiseReductionEnabled = audioSettings.micNoiseReductionEnabled
        micNoiseReductionIntensity = audioSettings.micNoiseReductionIntensity
      }
      syncAudioRegionsToPlayer()
      syncAudioVolumes()
      syncNoiseReduction()
      regenerateSmoothedCursor()
    } else if hasWebcam {
      setCameraCorner(.bottomRight)
    }

    if let proj = project, let historyData = proj.loadHistory() {
      history.load(from: historyData)
    } else {
      history.pushSnapshot(createSnapshot())
    }

    startAutoSave()
  }

  func play() { playerController.play() }
  func pause() { playerController.pause() }

  func togglePlayPause() {
    if isPlaying {
      pause()
    } else {
      if trimEnd.isValid && CMTimeCompare(currentTime, trimEnd) >= 0 {
        seek(to: trimStart)
      }
      play()
    }
  }

  func skipForward(_ seconds: Double = 1.0) {
    let target = CMTimeAdd(currentTime, CMTime(seconds: seconds, preferredTimescale: 600))
    let clamped = CMTimeMinimum(target, trimEnd)
    seek(to: clamped)
  }

  func skipBackward(_ seconds: Double = 1.0) {
    let target = CMTimeSubtract(currentTime, CMTime(seconds: seconds, preferredTimescale: 600))
    let clamped = CMTimeMaximum(target, trimStart)
    seek(to: clamped)
  }

  func seek(to time: CMTime) {
    playerController.seek(to: time)
  }

  func updateTrimStart(_ time: CMTime) {
    trimStart = time
  }

  func updateTrimEnd(_ time: CMTime) {
    trimEnd = time
    playerController.trimEnd = time
  }

  func setBackgroundImage(from sourceURL: URL) {
    guard let bundleURL = project?.bundleURL else { return }
    let fm = FileManager.default
    let contents = (try? fm.contentsOfDirectory(atPath: bundleURL.path)) ?? []
    for file in contents where file.hasPrefix("background-image.") {
      try? fm.removeItem(at: bundleURL.appendingPathComponent(file))
    }
    let filename = "background-image.\(sourceURL.pathExtension.lowercased())"
    let destURL = bundleURL.appendingPathComponent(filename)
    guard (try? fm.copyItem(at: sourceURL, to: destURL)) != nil else { return }
    backgroundImage = NSImage(contentsOf: destURL)
    backgroundStyle = .image(filename)
  }

  func removeBackgroundImage() {
    if case .image(let filename) = backgroundStyle, let bundleURL = project?.bundleURL {
      let fileURL = bundleURL.appendingPathComponent(filename)
      try? FileManager.default.removeItem(at: fileURL)
    }
    backgroundImage = nil
    backgroundStyle = .solidColor(CodableColor(r: 0, g: 0, b: 0))
  }

  func backgroundImageURL() -> URL? {
    guard case .image(let filename) = backgroundStyle, let bundleURL = project?.bundleURL else {
      return nil
    }
    return bundleURL.appendingPathComponent(filename)
  }

  private func regions(for trackType: AudioTrackType) -> [AudioRegionData] {
    switch trackType {
    case .system: return systemAudioRegions
    case .mic: return micAudioRegions
    }
  }

  private func setRegions(_ regions: [AudioRegionData], for trackType: AudioTrackType) {
    let sorted = regions.sorted { $0.startSeconds < $1.startSeconds }
    switch trackType {
    case .system: systemAudioRegions = sorted
    case .mic: micAudioRegions = sorted
    }
    syncAudioRegionsToPlayer()
  }

  func updateRegionStart(trackType: AudioTrackType, regionId: UUID, newStart: Double) {
    var regs = regions(for: trackType)
    guard let idx = regs.firstIndex(where: { $0.id == regionId }) else { return }
    let minStart: Double = idx > 0 ? regs[idx - 1].endSeconds : 0
    let maxStart = regs[idx].endSeconds - 0.01
    regs[idx].startSeconds = max(minStart, min(maxStart, newStart))
    setRegions(regs, for: trackType)
  }

  func updateRegionEnd(trackType: AudioTrackType, regionId: UUID, newEnd: Double) {
    var regs = regions(for: trackType)
    guard let idx = regs.firstIndex(where: { $0.id == regionId }) else { return }
    let dur = CMTimeGetSeconds(duration)
    let maxEnd: Double = idx < regs.count - 1 ? regs[idx + 1].startSeconds : dur
    let minEnd = regs[idx].startSeconds + 0.01
    regs[idx].endSeconds = max(minEnd, min(maxEnd, newEnd))
    setRegions(regs, for: trackType)
  }

  func moveRegion(trackType: AudioTrackType, regionId: UUID, newStart: Double) {
    var regs = regions(for: trackType)
    guard let idx = regs.firstIndex(where: { $0.id == regionId }) else { return }
    let dur = CMTimeGetSeconds(duration)
    let regionDuration = regs[idx].endSeconds - regs[idx].startSeconds
    let minStart: Double = idx > 0 ? regs[idx - 1].endSeconds : 0
    let maxStart: Double = (idx < regs.count - 1 ? regs[idx + 1].startSeconds : dur) - regionDuration
    let clampedStart = max(minStart, min(maxStart, newStart))
    regs[idx].startSeconds = clampedStart
    regs[idx].endSeconds = clampedStart + regionDuration
    setRegions(regs, for: trackType)
  }

  func addRegion(trackType: AudioTrackType, atTime time: Double) {
    var regs = regions(for: trackType)
    let dur = CMTimeGetSeconds(duration)
    let desiredHalf = min(5.0, dur / 2)

    var gapStart: Double = 0
    var gapEnd: Double = dur
    var insertIdx = regs.count

    for i in 0..<regs.count {
      if time < regs[i].startSeconds {
        gapEnd = regs[i].startSeconds
        insertIdx = i
        break
      }
      gapStart = regs[i].endSeconds
    }
    if insertIdx == regs.count {
      gapEnd = dur
    }

    guard gapEnd - gapStart >= 0.05 else { return }

    let regionStart = max(gapStart, time - desiredHalf)
    let regionEnd = min(gapEnd, time + desiredHalf)
    let finalStart = max(gapStart, min(regionStart, regionEnd - 0.05))
    let finalEnd = min(gapEnd, max(regionEnd, finalStart + 0.05))

    regs.insert(AudioRegionData(startSeconds: finalStart, endSeconds: finalEnd), at: insertIdx)
    setRegions(regs, for: trackType)
  }

  func removeRegion(trackType: AudioTrackType, regionId: UUID) {
    var regs = regions(for: trackType)
    regs.removeAll { $0.id == regionId }
    setRegions(regs, for: trackType)
  }

  func syncAudioRegionsToPlayer() {
    playerController.systemAudioRegions = systemAudioRegions.map { region in
      (
        start: CMTime(seconds: region.startSeconds, preferredTimescale: 600),
        end: CMTime(seconds: region.endSeconds, preferredTimescale: 600)
      )
    }
    playerController.micAudioRegions = micAudioRegions.map { region in
      (
        start: CMTime(seconds: region.startSeconds, preferredTimescale: 600),
        end: CMTime(seconds: region.endSeconds, preferredTimescale: 600)
      )
    }
  }

  func syncAudioVolumes() {
    playerController.setSystemAudioVolume(effectiveSystemAudioVolume)
    playerController.setMicAudioVolume(effectiveMicAudioVolume)
  }

  func syncNoiseReduction() {
    regenerateProcessedMicAudio()
  }

  func regenerateProcessedMicAudio() {
    micProcessingTask?.cancel()
    guard let micURL = result.microphoneAudioURL, micNoiseReductionEnabled else {
      if let old = processedMicAudioURL {
        if !isURLInsideProjectBundle(old) {
          try? FileManager.default.removeItem(at: old)
        }
        processedMicAudioURL = nil
      }
      isMicProcessing = false
      if let micURL = result.microphoneAudioURL {
        playerController.swapMicAudioFile(url: micURL)
      }
      return
    }

    let intensity = micNoiseReductionIntensity

    if let proj = project,
      let cachedURL = proj.denoisedMicAudioURL,
      let cachedIntensity = proj.metadata.editorState?.audioSettings?.cachedNoiseReductionIntensity,
      abs(cachedIntensity - intensity) < 0.001
    {
      let oldURL = processedMicAudioURL
      processedMicAudioURL = cachedURL
      isMicProcessing = false
      playerController.swapMicAudioFile(url: cachedURL)
      if let oldURL, oldURL != cachedURL, !isURLInsideProjectBundle(oldURL) {
        try? FileManager.default.removeItem(at: oldURL)
      }
      return
    }

    isMicProcessing = true
    micProcessingProgress = 0
    let state = self
    micProcessingTask = Task {
      try? await Task.sleep(for: .milliseconds(500))
      guard !Task.isCancelled else { return }

      let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("reframed-nr-preview-\(UUID().uuidString).m4a")

      do {
        try await RNNoiseProcessor.processFile(
          inputURL: micURL,
          outputURL: tempURL,
          intensity: intensity,
          onProgress: { progress in
            state.micProcessingProgress = progress
          }
        )
        guard !Task.isCancelled else {
          try? FileManager.default.removeItem(at: tempURL)
          return
        }

        var finalURL = tempURL
        if let proj = state.project {
          let destURL = proj.denoisedMicAudioDestinationURL
          try? FileManager.default.removeItem(at: destURL)
          do {
            try FileManager.default.copyItem(at: tempURL, to: destURL)
            try? FileManager.default.removeItem(at: tempURL)
            finalURL = destURL
          } catch {
            state.logger.warning("Failed to cache denoised audio in bundle: \(error)")
          }
        }

        let oldURL = state.processedMicAudioURL
        state.processedMicAudioURL = finalURL
        state.isMicProcessing = false
        state.playerController.swapMicAudioFile(url: finalURL)
        if let oldURL, oldURL != finalURL, !state.isURLInsideProjectBundle(oldURL) {
          try? FileManager.default.removeItem(at: oldURL)
        }
        state.scheduleSave()
      } catch {
        guard !Task.isCancelled else {
          try? FileManager.default.removeItem(at: tempURL)
          return
        }
        state.isMicProcessing = false
        state.logger.error("Mic noise reduction failed: \(error)")
      }
    }
  }

  private func isURLInsideProjectBundle(_ url: URL) -> Bool {
    guard let bundleURL = project?.bundleURL else { return false }
    return url.path.hasPrefix(bundleURL.path)
  }

  func isCameraFullscreen(at time: Double) -> Bool {
    cameraFullscreenRegions.contains { time >= $0.startSeconds && time <= $0.endSeconds }
  }

  func addCameraRegion(atTime time: Double) {
    let dur = CMTimeGetSeconds(duration)
    let desiredHalf = min(5.0, dur / 2)
    var gapStart: Double = 0
    var gapEnd: Double = dur
    var insertIdx = cameraFullscreenRegions.count

    for i in 0..<cameraFullscreenRegions.count {
      if time < cameraFullscreenRegions[i].startSeconds {
        gapEnd = cameraFullscreenRegions[i].startSeconds
        insertIdx = i
        break
      }
      gapStart = cameraFullscreenRegions[i].endSeconds
    }
    if insertIdx == cameraFullscreenRegions.count {
      gapEnd = dur
    }

    guard gapEnd - gapStart >= 0.05 else { return }

    let regionStart = max(gapStart, time - desiredHalf)
    let regionEnd = min(gapEnd, time + desiredHalf)
    let finalStart = max(gapStart, min(regionStart, regionEnd - 0.05))
    let finalEnd = min(gapEnd, max(regionEnd, finalStart + 0.05))

    cameraFullscreenRegions.insert(
      AudioRegionData(startSeconds: finalStart, endSeconds: finalEnd),
      at: insertIdx
    )
    cameraFullscreenRegions.sort { $0.startSeconds < $1.startSeconds }
  }

  func removeCameraRegion(regionId: UUID) {
    cameraFullscreenRegions.removeAll { $0.id == regionId }
  }

  func updateCameraRegionStart(regionId: UUID, newStart: Double) {
    guard let idx = cameraFullscreenRegions.firstIndex(where: { $0.id == regionId }) else { return }
    let minStart: Double = idx > 0 ? cameraFullscreenRegions[idx - 1].endSeconds : 0
    let maxStart = cameraFullscreenRegions[idx].endSeconds - 0.01
    cameraFullscreenRegions[idx].startSeconds = max(minStart, min(maxStart, newStart))
    cameraFullscreenRegions.sort { $0.startSeconds < $1.startSeconds }
  }

  func updateCameraRegionEnd(regionId: UUID, newEnd: Double) {
    guard let idx = cameraFullscreenRegions.firstIndex(where: { $0.id == regionId }) else { return }
    let dur = CMTimeGetSeconds(duration)
    let maxEnd: Double =
      idx < cameraFullscreenRegions.count - 1
      ? cameraFullscreenRegions[idx + 1].startSeconds : dur
    let minEnd = cameraFullscreenRegions[idx].startSeconds + 0.01
    cameraFullscreenRegions[idx].endSeconds = max(minEnd, min(maxEnd, newEnd))
    cameraFullscreenRegions.sort { $0.startSeconds < $1.startSeconds }
  }

  func moveCameraRegion(regionId: UUID, newStart: Double) {
    guard let idx = cameraFullscreenRegions.firstIndex(where: { $0.id == regionId }) else { return }
    let dur = CMTimeGetSeconds(duration)
    let regionDuration = cameraFullscreenRegions[idx].endSeconds - cameraFullscreenRegions[idx].startSeconds
    let minStart: Double = idx > 0 ? cameraFullscreenRegions[idx - 1].endSeconds : 0
    let maxStart: Double =
      (idx < cameraFullscreenRegions.count - 1
        ? cameraFullscreenRegions[idx + 1].startSeconds : dur) - regionDuration
    let clampedStart = max(minStart, min(maxStart, newStart))
    cameraFullscreenRegions[idx].startSeconds = clampedStart
    cameraFullscreenRegions[idx].endSeconds = clampedStart + regionDuration
    cameraFullscreenRegions.sort { $0.startSeconds < $1.startSeconds }
  }

  func setCameraCorner(_ corner: CameraCorner) {
    let margin: CGFloat = 0.02
    let canvas = canvasSize(for: result.screenSize)
    let marginY = margin * canvas.width / max(canvas.height, 1)
    let relH = cameraRelativeHeight

    switch corner {
    case .topLeft:
      cameraLayout.relativeX = margin
      cameraLayout.relativeY = marginY
    case .topRight:
      cameraLayout.relativeX = 1.0 - cameraLayout.relativeWidth - margin
      cameraLayout.relativeY = marginY
    case .bottomLeft:
      cameraLayout.relativeX = margin
      cameraLayout.relativeY = 1.0 - relH - marginY
    case .bottomRight:
      cameraLayout.relativeX = 1.0 - cameraLayout.relativeWidth - margin
      cameraLayout.relativeY = 1.0 - relH - marginY
    }
  }

  func clampCameraPosition() {
    cameraLayout.relativeWidth = min(cameraLayout.relativeWidth, maxCameraRelativeWidth)
    let relH = cameraRelativeHeight
    cameraLayout.relativeX = max(0, min(1 - cameraLayout.relativeWidth, cameraLayout.relativeX))
    cameraLayout.relativeY = max(0, min(1 - relH, cameraLayout.relativeY))
  }

  var maxCameraRelativeWidth: CGFloat {
    guard let ws = result.webcamSize else { return 1.0 }
    let canvas = canvasSize(for: result.screenSize)
    let hwRatio = cameraAspect.heightToWidthRatio(webcamSize: ws)
    let canvasRatio = canvas.width / max(canvas.height, 1)
    return min(1.0, 1.0 / max(hwRatio * canvasRatio, 0.001))
  }

  private var cameraRelativeHeight: CGFloat {
    guard let ws = result.webcamSize else { return cameraLayout.relativeWidth * 0.75 }
    let canvas = canvasSize(for: result.screenSize)
    let aspect = cameraAspect.heightToWidthRatio(webcamSize: ws)
    return cameraLayout.relativeWidth * aspect * (canvas.width / max(canvas.height, 1))
  }

  func canvasSize(for screenSize: CGSize) -> CGSize {
    if let base = canvasAspect.size(for: screenSize) {
      return base
    }
    if padding > 0 {
      let scale = 1.0 + 2.0 * padding
      return CGSize(width: screenSize.width * scale, height: screenSize.height * scale)
    }
    return screenSize
  }

  func export(settings: ExportSettings) async throws -> URL {
    isExporting = true
    exportProgress = 0
    exportETA = nil
    exportStatusMessage = nil
    defer {
      isExporting = false
      exportTask = nil
      exportStatusMessage = nil
    }

    if isMicProcessing {
      exportStatusMessage =
        "Waiting for noise reduction… \(Int(micProcessingProgress * 100))%"
      while isMicProcessing {
        try await Task.sleep(for: .milliseconds(100))
        exportStatusMessage =
          "Waiting for noise reduction… \(Int(micProcessingProgress * 100))%"
      }
      exportStatusMessage = nil
    }

    let cursorSnapshot = showCursor ? activeCursorProvider?.makeSnapshot() : nil

    let sysRegions = systemAudioRegions.map {
      CMTimeRange(
        start: CMTime(seconds: $0.startSeconds, preferredTimescale: 600),
        end: CMTime(seconds: $0.endSeconds, preferredTimescale: 600)
      )
    }
    let micRegions = micAudioRegions.map {
      CMTimeRange(
        start: CMTime(seconds: $0.startSeconds, preferredTimescale: 600),
        end: CMTime(seconds: $0.endSeconds, preferredTimescale: 600)
      )
    }
    let camFsRegions = cameraFullscreenRegions.map {
      CMTimeRange(
        start: CMTime(seconds: $0.startSeconds, preferredTimescale: 600),
        end: CMTime(seconds: $0.endSeconds, preferredTimescale: 600)
      )
    }

    let exportResult: RecordingResult
    if webcamEnabled {
      exportResult = result
    } else {
      exportResult = RecordingResult(
        screenVideoURL: result.screenVideoURL,
        webcamVideoURL: nil,
        systemAudioURL: result.systemAudioURL,
        microphoneAudioURL: result.microphoneAudioURL,
        cursorMetadataURL: result.cursorMetadataURL,
        screenSize: result.screenSize,
        webcamSize: nil,
        fps: result.fps,
        captureQuality: result.captureQuality
      )
    }

    let state = self
    let url = try await VideoCompositor.export(
      result: exportResult,
      cameraLayout: cameraLayout,
      cameraAspect: cameraAspect,
      trimRange: CMTimeRange(start: trimStart, end: trimEnd),
      systemAudioRegions: sysRegions.isEmpty ? nil : sysRegions,
      micAudioRegions: micRegions.isEmpty ? nil : micRegions,
      cameraFullscreenRegions: camFsRegions.isEmpty ? nil : camFsRegions,
      backgroundStyle: backgroundStyle,
      backgroundImageURL: backgroundImageURL(),
      backgroundImageFillMode: backgroundImageFillMode,
      canvasAspect: canvasAspect,
      padding: padding,
      videoCornerRadius: videoCornerRadius,
      cameraCornerRadius: cameraCornerRadius,
      cameraBorderWidth: cameraBorderWidth,
      cameraBorderColor: cameraBorderColor,
      videoShadow: videoShadow,
      cameraShadow: cameraShadow,
      cameraMirrored: cameraMirrored,
      cameraFullscreenFillMode: cameraFullscreenFillMode,
      cameraFullscreenAspect: cameraFullscreenAspect,
      exportSettings: settings,
      cursorSnapshot: cursorSnapshot,
      cursorStyle: cursorStyle,
      cursorSize: cursorSize,
      showClickHighlights: showClickHighlights,
      clickHighlightColor: clickHighlightColor.cgColor,
      clickHighlightSize: clickHighlightSize,
      zoomFollowCursor: zoomFollowCursor,
      zoomTimeline: zoomTimeline,
      systemAudioVolume: effectiveSystemAudioVolume,
      micAudioVolume: effectiveMicAudioVolume,
      micNoiseReductionEnabled: micNoiseReductionEnabled,
      micNoiseReductionIntensity: micNoiseReductionIntensity,
      processedMicAudioURL: processedMicAudioURL,
      progressHandler: { progress, eta in
        state.exportProgress = progress
        state.exportETA = eta
      }
    )
    exportProgress = 1.0
    lastExportedURL = url
    logger.info("Export finished: \(url.path)")
    return url
  }

  func cancelExport() {
    exportTask?.cancel()
    exportTask = nil
  }

  func deleteRecording() {
    if let project {
      try? project.delete()
    } else {
      let fm = FileManager.default
      try? fm.removeItem(at: result.screenVideoURL)
      if let webcamURL = result.webcamVideoURL {
        try? fm.removeItem(at: webcamURL)
      }
      if let sysURL = result.systemAudioURL {
        try? fm.removeItem(at: sysURL)
      }
      if let micURL = result.microphoneAudioURL {
        try? fm.removeItem(at: micURL)
      }
    }
  }

  func openProjectFolder() {
    if let bundleURL = project?.bundleURL {
      NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
    } else {
      let dir = FileManager.default.projectSaveDirectory()
      NSWorkspace.shared.open(dir)
    }
  }

  func openExportedFile() {
    if let lastExportedURL {
      NSWorkspace.shared.activateFileViewerSelecting([lastExportedURL])
    } else {
      let dir = FileManager.default.defaultSaveDirectory()
      NSWorkspace.shared.open(dir)
    }
  }

  func renameProject(_ newName: String) {
    guard var proj = project else { return }
    try? proj.rename(to: newName)
    project = proj
    result = proj.recordingResult
    projectName = proj.name
  }

  func saveState() {
    guard let project else { return }
    try? project.saveEditorState(createSnapshot())
  }

  func generateAutoZoom() {
    guard let provider = cursorMetadataProvider else { return }
    let config = ZoomDetectorConfig(
      zoomLevel: zoomLevel,
      dwellThresholdSeconds: zoomDwellThreshold,
      velocityThreshold: 0.05,
      minZoomDuration: 1.0,
      transitionDuration: zoomTransitionSpeed
    )
    let dur = CMTimeGetSeconds(duration)
    var newKeyframes = ZoomDetector.detect(from: provider.metadata, duration: dur, config: config)

    if let existing = zoomTimeline {
      let autoRegions = groupZoomRegions(from: newKeyframes)
      let manualKeyframes = existing.allKeyframes.filter { !$0.isAuto }
      let manualRegions = groupZoomRegions(from: manualKeyframes)

      for manualRegion in manualRegions {
        let overlaps = autoRegions.contains { auto in
          manualRegion.startTime < auto.endTime && manualRegion.endTime > auto.startTime
        }
        if !overlaps {
          let regionKfs = Array(manualKeyframes[manualRegion.startIndex..<(manualRegion.startIndex + manualRegion.count)])
          newKeyframes.append(contentsOf: regionKfs)
        }
      }
    }

    zoomTimeline = ZoomTimeline(keyframes: newKeyframes)
  }

  func clearAutoZoom() {
    guard let existing = zoomTimeline else { return }
    let manualKeyframes = existing.allKeyframes.filter { !$0.isAuto }
    if manualKeyframes.isEmpty {
      zoomTimeline = nil
    } else {
      zoomTimeline = ZoomTimeline(keyframes: manualKeyframes)
    }
  }

  func addManualZoomKeyframe(at time: Double, center: CGPoint) {
    let dur = CMTimeGetSeconds(duration)
    let holdDuration = min(10.0, dur / 2)
    let holdEnd = min(dur, time + holdDuration)
    let transIn = max(0, time - zoomTransitionSpeed)
    let transOut = min(dur, holdEnd + zoomTransitionSpeed)

    if let existing = zoomTimeline {
      let existingRegions = groupZoomRegions(from: existing.allKeyframes)
      let overlaps = existingRegions.contains { region in
        transIn < region.endTime && transOut > region.startTime
      }
      if overlaps { return }
    }

    let newKeyframes: [ZoomKeyframe] = [
      ZoomKeyframe(t: transIn, zoomLevel: 1.0, centerX: center.x, centerY: center.y, isAuto: false),
      ZoomKeyframe(t: time, zoomLevel: zoomLevel, centerX: center.x, centerY: center.y, isAuto: false),
      ZoomKeyframe(t: holdEnd, zoomLevel: zoomLevel, centerX: center.x, centerY: center.y, isAuto: false),
      ZoomKeyframe(t: transOut, zoomLevel: 1.0, centerX: center.x, centerY: center.y, isAuto: false),
    ]

    var existing = zoomTimeline?.allKeyframes ?? []
    existing.append(contentsOf: newKeyframes)
    zoomTimeline = ZoomTimeline(keyframes: existing)
  }

  func removeZoomKeyframe(at index: Int) {
    guard let existing = zoomTimeline else { return }
    var kfs = existing.allKeyframes
    guard index >= 0 && index < kfs.count else { return }
    kfs.remove(at: index)
    if kfs.isEmpty {
      zoomTimeline = nil
    } else {
      zoomTimeline = ZoomTimeline(keyframes: kfs)
    }
  }

  func removeZoomRegion(startIndex: Int, count: Int) {
    guard let existing = zoomTimeline else { return }
    var kfs = existing.allKeyframes
    let endIndex = startIndex + count
    guard startIndex >= 0 && endIndex <= kfs.count else { return }
    kfs.removeSubrange(startIndex..<endIndex)
    if kfs.isEmpty {
      zoomTimeline = nil
    } else {
      zoomTimeline = ZoomTimeline(keyframes: kfs)
    }
  }

  func updateZoomRegion(startIndex: Int, count: Int, newKeyframes: [ZoomKeyframe]) {
    guard let existing = zoomTimeline else { return }
    var kfs = existing.allKeyframes
    let endIndex = startIndex + count
    guard startIndex >= 0 && endIndex <= kfs.count else { return }
    kfs.replaceSubrange(startIndex..<endIndex, with: newKeyframes)
    zoomTimeline = ZoomTimeline(keyframes: kfs)
  }

  var activeCursorProvider: CursorMetadataProvider? {
    cursorMovementEnabled ? smoothedCursorProvider : cursorMetadataProvider
  }

  func regenerateSmoothedCursor() {
    guard let provider = cursorMetadataProvider else {
      smoothedCursorProvider = nil
      return
    }
    guard cursorMovementEnabled else {
      smoothedCursorProvider = nil
      return
    }
    let smoothedSamples = CursorSmoothing.smooth(
      samples: provider.metadata.samples,
      speed: cursorMovementSpeed
    )
    var smoothedMetadata = provider.metadata
    smoothedMetadata.samples = smoothedSamples
    smoothedCursorProvider = CursorMetadataProvider(metadata: smoothedMetadata)
  }

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
        showClickHighlights: showClickHighlights,
        clickHighlightColor: clickHighlightColor,
        clickHighlightSize: clickHighlightSize
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
        cursorMovementSpeed: cursorMovementSpeed
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
      cameraFullscreenRegions: cameraFullscreenRegions.isEmpty ? nil : cameraFullscreenRegions
    )
  }

  func restoreFromSnapshot(_ data: EditorStateData) {
    isRestoringState = true
    pendingUndoTask?.cancel()

    let prev = createSnapshot()

    let start = CMTime(seconds: data.trimStartSeconds, preferredTimescale: 600)
    let end = CMTime(seconds: data.trimEndSeconds, preferredTimescale: 600)
    if CMTimeCompare(start, .zero) >= 0 && CMTimeCompare(end, start) > 0 {
      trimStart = start
      trimEnd = CMTimeMinimum(end, playerController.duration)
      playerController.trimEnd = trimEnd
    }

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
      cursorStyle = CursorStyle(rawValue: cursorSettings.cursorStyleRaw) ?? .defaultArrow
      cursorSize = cursorSettings.cursorSize
      showClickHighlights = cursorSettings.showClickHighlights
      if let savedColor = cursorSettings.clickHighlightColor {
        clickHighlightColor = savedColor
      }
      clickHighlightSize = cursorSettings.clickHighlightSize
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
    }

    if let savedSysRegions = data.systemAudioRegions, !savedSysRegions.isEmpty {
      systemAudioRegions = savedSysRegions
    }
    if let savedMicRegions = data.micAudioRegions, !savedMicRegions.isEmpty {
      micAudioRegions = savedMicRegions
    }
    if let savedCameraRegions = data.cameraFullscreenRegions, !savedCameraRegions.isEmpty {
      cameraFullscreenRegions = savedCameraRegions
    }

    if let audioSettings = data.audioSettings {
      systemAudioVolume = audioSettings.systemAudioVolume
      micAudioVolume = audioSettings.micAudioVolume
      systemAudioMuted = audioSettings.systemAudioMuted
      micAudioMuted = audioSettings.micAudioMuted
      micNoiseReductionEnabled = audioSettings.micNoiseReductionEnabled
      micNoiseReductionIntensity = audioSettings.micNoiseReductionIntensity
    }

    if case .image(let filename) = data.backgroundStyle, let bundleURL = project?.bundleURL {
      let url = bundleURL.appendingPathComponent(filename)
      backgroundImage = NSImage(contentsOf: url)
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

  private func startAutoSave() {
    observeChanges()
  }

  private func observeChanges() {
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
      _ = self.showCursor
      _ = self.cursorStyle
      _ = self.cursorSize
      _ = self.showClickHighlights
      _ = self.clickHighlightColor
      _ = self.clickHighlightSize
      _ = self.zoomEnabled
      _ = self.autoZoomEnabled
      _ = self.zoomFollowCursor
      _ = self.zoomLevel
      _ = self.zoomTransitionSpeed
      _ = self.zoomDwellThreshold
      _ = self.zoomTimeline
      _ = self.cursorMovementEnabled
      _ = self.cursorMovementSpeed
      _ = self.trimStart
      _ = self.trimEnd
      _ = self.systemAudioRegions
      _ = self.micAudioRegions
      _ = self.cameraFullscreenRegions
      _ = self.systemAudioVolume
      _ = self.micAudioVolume
      _ = self.systemAudioMuted
      _ = self.micAudioMuted
      _ = self.micNoiseReductionEnabled
      _ = self.micNoiseReductionIntensity
    } onChange: {
      Task { @MainActor [weak self] in
        guard let self else { return }
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

enum CameraCorner {
  case topLeft, topRight, bottomLeft, bottomRight
}
