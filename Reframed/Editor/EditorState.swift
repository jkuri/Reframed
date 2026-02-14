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
  var isPreviewMode = false

  var backgroundStyle: BackgroundStyle = .none
  var canvasAspect: CanvasAspect = .original
  var padding: CGFloat = 0
  var videoCornerRadius: CGFloat = 0
  var cameraCornerRadius: CGFloat = 8
  var cameraBorderWidth: CGFloat = 0
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
  var zoomDwellThreshold: Double = 2.5

  private let logger = Logger(label: "eu.jankuri.reframed.editor-state")

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
      self.cameraCornerRadius = saved.cameraCornerRadius
      self.cameraBorderWidth = saved.cameraBorderWidth
      self.cameraLayout = saved.cameraLayout
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
      if let savedSysRegions = saved.systemAudioRegions, !savedSysRegions.isEmpty {
        systemAudioRegions = savedSysRegions
      }
      if let savedMicRegions = saved.micAudioRegions, !savedMicRegions.isEmpty {
        micAudioRegions = savedMicRegions
      }
      if let savedCameraRegions = saved.cameraFullscreenRegions, !savedCameraRegions.isEmpty {
        cameraFullscreenRegions = savedCameraRegions
      }
      syncAudioRegionsToPlayer()
    } else if hasWebcam {
      setCameraCorner(.bottomRight)
    }
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
    let desiredHalf: Double = 1.0

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

  func isCameraFullscreen(at time: Double) -> Bool {
    cameraFullscreenRegions.contains { time >= $0.startSeconds && time <= $0.endSeconds }
  }

  func addCameraRegion(atTime time: Double) {
    let dur = CMTimeGetSeconds(duration)
    let desiredHalf: Double = 1.0
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
    let relH = cameraRelativeHeight

    switch corner {
    case .topLeft:
      cameraLayout.relativeX = margin
      cameraLayout.relativeY = margin
    case .topRight:
      cameraLayout.relativeX = 1.0 - cameraLayout.relativeWidth - margin
      cameraLayout.relativeY = margin
    case .bottomLeft:
      cameraLayout.relativeX = margin
      cameraLayout.relativeY = 1.0 - relH - margin
    case .bottomRight:
      cameraLayout.relativeX = 1.0 - cameraLayout.relativeWidth - margin
      cameraLayout.relativeY = 1.0 - relH - margin
    }
  }

  func clampCameraPosition() {
    let relH = cameraRelativeHeight
    cameraLayout.relativeX = max(0, min(1 - cameraLayout.relativeWidth, cameraLayout.relativeX))
    cameraLayout.relativeY = max(0, min(1 - relH, cameraLayout.relativeY))
  }

  private var cameraRelativeHeight: CGFloat {
    guard let ws = result.webcamSize else { return cameraLayout.relativeWidth * 0.75 }
    let canvas = canvasSize(for: result.screenSize)
    let aspect = ws.height / max(ws.width, 1)
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
    defer {
      isExporting = false
      exportTask = nil
    }

    let cursorSnapshot = showCursor ? cursorMetadataProvider?.makeSnapshot() : nil

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

    let state = self
    let url = try await VideoCompositor.export(
      result: result,
      cameraLayout: cameraLayout,
      trimRange: CMTimeRange(start: trimStart, end: trimEnd),
      systemAudioRegions: sysRegions.isEmpty ? nil : sysRegions,
      micAudioRegions: micRegions.isEmpty ? nil : micRegions,
      cameraFullscreenRegions: camFsRegions.isEmpty ? nil : camFsRegions,
      backgroundStyle: backgroundStyle,
      canvasAspect: canvasAspect,
      padding: padding,
      videoCornerRadius: videoCornerRadius,
      cameraCornerRadius: cameraCornerRadius,
      cameraBorderWidth: cameraBorderWidth,
      exportSettings: settings,
      cursorSnapshot: cursorSnapshot,
      cursorStyle: cursorStyle,
      cursorSize: cursorSize,
      showClickHighlights: showClickHighlights,
      clickHighlightColor: clickHighlightColor.cgColor,
      clickHighlightSize: clickHighlightSize,
      zoomFollowCursor: zoomFollowCursor,
      zoomTimeline: zoomTimeline,
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
    let data = EditorStateData(
      trimStartSeconds: CMTimeGetSeconds(trimStart),
      trimEndSeconds: CMTimeGetSeconds(trimEnd),
      backgroundStyle: backgroundStyle,
      canvasAspect: canvasAspect,
      padding: padding,
      videoCornerRadius: videoCornerRadius,
      cameraCornerRadius: cameraCornerRadius,
      cameraBorderWidth: cameraBorderWidth,
      cameraLayout: cameraLayout,
      cursorSettings: cursorSettings,
      zoomSettings: zoomSettings,
      systemAudioRegions: systemAudioRegions.isEmpty ? nil : systemAudioRegions,
      micAudioRegions: micAudioRegions.isEmpty ? nil : micAudioRegions,
      cameraFullscreenRegions: cameraFullscreenRegions.isEmpty ? nil : cameraFullscreenRegions
    )
    try? project.saveEditorState(data)
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
    let holdDuration = max(zoomDwellThreshold, 0.5)
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

  func teardown() {
    saveState()
    playerController.teardown()
  }
}

enum CameraCorner {
  case topLeft, topRight, bottomLeft, bottomRight
}
