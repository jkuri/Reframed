import AVFoundation
import AppKit
import CoreMedia
import Foundation
import Logging

@MainActor
@Observable
final class EditorState {
  var result: RecordingResult
  var project: ReframedProject?
  var playerController: SyncedPlayerController
  var cameraLayout = CameraLayout()
  var trimStart: CMTime = .zero
  var trimEnd: CMTime = .zero
  var systemAudioRegions: [AudioRegionData] = []
  var micAudioRegions: [AudioRegionData] = []
  var cameraRegions: [CameraRegionData] = []
  var videoRegions: [VideoRegionData] = []
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
  var cursorStyle: CursorStyle = .centerDefault
  var cursorSize: CGFloat = 24

  var cursorFillColor: CodableColor = CodableColor(r: 1, g: 1, b: 1)
  var cursorStrokeColor: CodableColor = CodableColor(r: 0, g: 0, b: 0)

  var showClickHighlights: Bool = false
  var clickHighlightColor: CodableColor = CodableColor(r: 0, g: 0, b: 0, a: 1.0)
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
  var smoothedCursorProvider: CursorMetadataProvider?

  var history = History()
  var isRestoringState = false
  var pendingUndoTask: Task<Void, Never>?

  let logger = Logger(label: "eu.jankuri.reframed.editor-state")
  var pendingSaveTask: Task<Void, Never>?

  var systemAudioVolume: Float = 1.0
  var micAudioVolume: Float = 1.0
  var systemAudioMuted: Bool = false
  var micAudioMuted: Bool = false
  var micNoiseReductionEnabled: Bool = false
  var micNoiseReductionIntensity: Float = 0.5

  var webcamEnabled: Bool = true
  var cameraBackgroundStyle: CameraBackgroundStyle = .none
  var cameraBackgroundImage: NSImage?

  var processedMicAudioURL: URL?
  var isMicProcessing: Bool = false
  var micProcessingProgress: Double = 0
  var micProcessingTask: Task<Void, Never>?

  var hasSystemAudio: Bool { result.systemAudioURL != nil }
  var hasMicAudio: Bool { result.microphoneAudioURL != nil }

  var effectiveSystemAudioVolume: Float { systemAudioMuted ? 0 : systemAudioVolume }
  var effectiveMicAudioVolume: Float { micAudioMuted ? 0 : micAudioVolume }

  var isPlaying: Bool { playerController.isPlaying }
  var currentTime: CMTime { playerController.currentTime }
  var duration: CMTime { playerController.duration }
  var hasWebcam: Bool { result.webcamVideoURL != nil }

  var videoRegionsTotalDuration: Double {
    videoRegions.reduce(0) { $0 + ($1.endSeconds - $1.startSeconds) }
  }

  var hasVideoRegionCuts: Bool {
    let dur = CMTimeGetSeconds(duration)
    guard !videoRegions.isEmpty else { return false }
    return abs(videoRegionsTotalDuration - dur) > 0.01
  }

  var previewElapsedTime: Double {
    let t = CMTimeGetSeconds(currentTime)
    var elapsed = 0.0
    for region in videoRegions {
      if t >= region.endSeconds {
        elapsed += region.endSeconds - region.startSeconds
      } else if t >= region.startSeconds {
        elapsed += t - region.startSeconds
        break
      } else {
        break
      }
    }
    return elapsed
  }

  func sourceTimeForPreviewElapsed(_ elapsed: Double) -> Double {
    var remaining = elapsed
    for region in videoRegions {
      let regionDur = region.endSeconds - region.startSeconds
      if remaining <= regionDur {
        return region.startSeconds + remaining
      }
      remaining -= regionDur
    }
    if let last = videoRegions.last {
      return last.endSeconds
    }
    return 0
  }

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
      self.cameraBackgroundStyle = saved.cameraBackgroundStyle ?? .none
      if case .image(let filename) = saved.cameraBackgroundStyle {
        let url = project.bundleURL.appendingPathComponent(filename)
        self.cameraBackgroundImage = NSImage(contentsOf: url)
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
    videoRegions = [VideoRegionData(startSeconds: 0, endSeconds: dur)]
    playerController.trimEnd = trimEnd
    syncAudioRegionsToPlayer()
    playerController.setupTimeObserver()

    if let cursorURL = project?.cursorMetadataURL ?? result.cursorMetadataURL {
      do {
        cursorMetadataProvider = try CursorMetadataProvider.load(from: cursorURL)
      } catch {
        logger.error("Failed to load cursor metadata: \(error)")
      }
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
        cursorStyle = CursorStyle(rawValue: cursorSettings.cursorStyleRaw) ?? .centerDefault
        cursorSize = cursorSettings.cursorSize
        cursorFillColor = cursorSettings.cursorFillColor ?? CodableColor(r: 1, g: 1, b: 1)
        cursorStrokeColor = cursorSettings.cursorStrokeColor ?? CodableColor(r: 0, g: 0, b: 0)
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
      if let savedCameraRegions = saved.cameraRegions, !savedCameraRegions.isEmpty {
        cameraRegions = savedCameraRegions
      } else if let legacyRegions = saved.cameraFullscreenRegions, !legacyRegions.isEmpty {
        cameraRegions = legacyRegions.map {
          CameraRegionData(id: $0.id, startSeconds: $0.startSeconds, endSeconds: $0.endSeconds, type: .fullscreen)
        }
      }
      if let savedVideoRegions = saved.videoRegions, !savedVideoRegions.isEmpty {
        videoRegions = savedVideoRegions
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

    trimStart = .zero
    trimEnd = playerController.duration
    playerController.trimEnd = playerController.duration

    if let proj = project, let historyData = proj.loadHistory() {
      history.load(from: historyData)
    } else {
      history.pushSnapshot(createSnapshot())
    }

    startAutoSave()
  }
}
