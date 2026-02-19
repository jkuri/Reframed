import AppKit
import Foundation
import Logging
import ScreenCaptureKit
import SwiftUI

enum CameraPreviewState {
  case off
  case starting
  case previewing
  case failed(String)
}

@MainActor
@Observable
final class SessionState {
  var state: CaptureState = .idle
  var lastRecordingURL: URL?
  var captureMode: CaptureMode = .none
  var errorMessage: String?
  var cameraPreviewState: CameraPreviewState = .off
  var isCameraOn = false
  var isMicrophoneOn = false
  var micAudioLevel: Float = 0
  var systemAudioLevel: Float = 0
  let options = RecordingOptions()

  weak var statusItemButton: NSStatusBarButton?

  private let logger = Logger(label: "eu.jankuri.reframed.session")
  private var selectionCoordinator: SelectionCoordinator?
  private var windowSelectionCoordinator: WindowSelectionCoordinator?
  private var recordingCoordinator: RecordingCoordinator?
  private var captureTarget: CaptureTarget?
  private var toolbarWindow: CaptureToolbarWindow?
  private var startRecordingWindow: StartRecordingWindow?
  private var editorWindows: [EditorWindow] = []
  private var webcamPreviewWindow: WebcamPreviewWindow?
  private var countdownOverlayWindow: CountdownOverlayWindow?
  private var countdownTask: Task<Void, Never>?
  private var persistentWebcam: WebcamCapture?
  private var verifiedCameraInfo: VerifiedCamera?
  private var mouseClickMonitor: MouseClickMonitor?
  private var cursorMetadataRecorder: CursorMetadataRecorder?
  private var devicePreviewWindow: DevicePreviewWindow?
  private var deviceCapture: DeviceCapture?
  private var audioLevelTask: Task<Void, Never>?

  weak var overlayView: SelectionOverlayView?

  func toggleCamera() {
    guard options.selectedCamera != nil else { return }
    isCameraOn.toggle()
    if isCameraOn {
      startCameraPreview()
    } else {
      stopCameraPreview()
    }
  }

  func toggleMicrophone() {
    guard options.selectedMicrophone != nil else { return }
    isMicrophoneOn.toggle()
  }

  private func startCameraPreview() {
    guard let cam = options.selectedCamera else { return }

    stopCameraPreview()
    cameraPreviewState = .starting

    let previewWindow = WebcamPreviewWindow()
    previewWindow.showLoading()
    webcamPreviewWindow = previewWindow

    Task {
      do {
        let (maxW, maxH) = Self.cameraMaxDimensions(for: ConfigService.shared.cameraMaximumResolution)
        let webcam = WebcamCapture()
        let info = try await webcam.startAndVerify(
          deviceId: cam.id,
          fps: options.fps,
          maxWidth: maxW,
          maxHeight: maxH
        )
        guard isCameraOn, options.selectedCamera?.id == cam.id else {
          webcam.stop()
          return
        }
        persistentWebcam = webcam
        verifiedCameraInfo = info
        cameraPreviewState = .previewing

        if let session = webcam.captureSession {
          previewWindow.show(captureSession: session)
        }
        logger.info("Camera preview started: \(info.width)x\(info.height)")
      } catch {
        guard isCameraOn, options.selectedCamera?.id == cam.id else { return }
        cameraPreviewState = .failed(error.localizedDescription)
        previewWindow.showError("Camera failed to start")
        logger.error("Camera preview failed: \(error)")
      }
    }
  }

  private func stopCameraPreview() {
    persistentWebcam?.stop()
    persistentWebcam = nil
    verifiedCameraInfo = nil
    webcamPreviewWindow?.close()
    webcamPreviewWindow = nil
    cameraPreviewState = .off
  }

  private func startAudioLevelPolling() {
    audioLevelTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self, let coordinator = self.recordingCoordinator else { break }
        let levels = await coordinator.getAudioLevels()
        self.micAudioLevel = levels.mic
        self.systemAudioLevel = levels.system
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
  }

  private func stopAudioLevelPolling() {
    audioLevelTask?.cancel()
    audioLevelTask = nil
    micAudioLevel = 0
    systemAudioLevel = 0
  }

  private static func cameraMaxDimensions(for resolution: String) -> (Int, Int) {
    switch resolution {
    case "720p":
      return (1280, 720)
    case "4K":
      return (3840, 2160)
    default:
      return (1920, 1080)
    }
  }

  func toggleToolbar() {
    if toolbarWindow != nil {
      hideToolbar()
    } else if case .editing = state {
      editorWindows.last?.bringToFront()
    } else {
      showToolbar()
    }
  }

  func showToolbar() {
    guard toolbarWindow == nil else { return }

    let window = CaptureToolbarWindow(session: self) { [weak self] in
      MainActor.assumeIsolated {
        self?.hideToolbar()
      }
    }
    toolbarWindow = window
    window.makeKeyAndOrderFront(nil)
  }

  func hideToolbar() {
    hideStartRecordingOverlay()
    toolbarWindow?.orderOut(nil)
    toolbarWindow?.contentView = nil
    toolbarWindow = nil
  }

  func selectMode(_ mode: CaptureMode) {
    captureMode = mode
    hideStartRecordingOverlay()

    switch mode {
    case .none:
      break
    case .entireScreen:
      showStartRecordingOverlay()
    case .selectedWindow:

      startWindowSelection()
    case .selectedArea:

      do {
        try beginSelection()
      } catch {
        logger.error("Failed to begin selection: \(error)")
      }
    case .device:
      break
    }
  }

  func startWindowSelection() {
    guard case .idle = state else { return }
    guard Permissions.hasScreenRecordingPermission else {
      Permissions.requestScreenRecordingPermission()
      return
    }

    transition(to: .selecting)
    captureTarget = nil

    let coordinator = WindowSelectionCoordinator()
    windowSelectionCoordinator = coordinator
    coordinator.beginSelection(session: self)
  }

  func beginSelection() throws {
    guard case .idle = state else {
      throw CaptureError.invalidTransition(from: "\(state)", to: "selecting")
    }

    guard Permissions.hasScreenRecordingPermission else {
      Permissions.requestScreenRecordingPermission()
      throw CaptureError.permissionDenied
    }

    transition(to: .selecting)
    captureTarget = nil

    let coordinator = SelectionCoordinator()
    selectionCoordinator = coordinator
    coordinator.beginSelection(session: self)

    if options.rememberLastSelection,
      let savedRect = StateService.shared.lastSelectionRect
    {
      let displayID = StateService.shared.lastDisplayID
      overlayView?.applyExternalRect(savedRect)
      captureTarget = .region(SelectionRect(rect: savedRect, displayID: displayID))
    }
  }

  func confirmSelection(_ selection: SelectionRect) {
    selectionCoordinator?.destroyOverlay()
    selectionCoordinator?.showRecordingBorder(screenRect: selection.rect)
    captureTarget = .region(selection)
    StateService.shared.lastSelectionRect = selection.rect
    StateService.shared.lastDisplayID = selection.displayID
    logger.info("Selection confirmed: \(selection.rect)")

    beginRecordingWithCountdown()
  }

  func confirmWindowSelection(_ window: SCWindow) {
    windowSelectionCoordinator?.destroyOverlay()
    windowSelectionCoordinator = nil

    captureTarget = .window(window)
    logger.info("Window selection confirmed: \(window.title ?? "Unknown")")

    let scFrame = window.frame
    if let screen = NSScreen.main {
      let screenHeight = screen.frame.height
      let appKitRect = CGRect(
        x: scFrame.origin.x,
        y: screenHeight - scFrame.origin.y - scFrame.height,
        width: scFrame.width,
        height: scFrame.height
      )
      let coordinator = SelectionCoordinator()
      selectionCoordinator = coordinator
      coordinator.showRecordingBorder(screenRect: appKitRect)
    }

    beginRecordingWithCountdown()
  }

  func updateWindowHighlight(_ window: SCWindow?) {
    windowSelectionCoordinator?.highlight(window: window)
  }

  func cancelSelection() {
    selectionCoordinator?.destroyAll()
    selectionCoordinator = nil
    windowSelectionCoordinator?.destroyOverlay()
    windowSelectionCoordinator = nil
    overlayView = nil
    transition(to: .idle)
    logger.info("Selection cancelled")
  }

  func updateOverlaySelection(_ rect: CGRect) {
    overlayView?.applyExternalRect(rect)
  }

  private func beginRecordingWithCountdown() {
    let delay = options.timerDelay.rawValue
    guard delay > 0 else {
      Task {
        do {
          try await startRecording()
        } catch {
          logger.error("Failed to start recording: \(error)")
          cleanupAfterRecordingFailure()
          showError(error.localizedDescription)
        }
      }
      return
    }

    transition(to: .countdown(remaining: delay))

    if let screen = NSScreen.main {
      let overlay = CountdownOverlayWindow(screen: screen, remaining: delay)
      overlay.orderFrontRegardless()
      countdownOverlayWindow = overlay
    }

    countdownTask = Task {
      var remaining = delay
      while remaining > 0 {
        try? await Task.sleep(for: .seconds(1))
        if Task.isCancelled { return }
        remaining -= 1
        if remaining > 0 {
          transition(to: .countdown(remaining: remaining))
          countdownOverlayWindow?.updateCountdown(remaining)
        }
      }

      dismissCountdownOverlay()

      do {
        try await startRecording()
      } catch {
        logger.error("Failed to start recording: \(error)")
        cleanupAfterRecordingFailure()
        showError(error.localizedDescription)
      }
    }
  }

  func cancelCountdown() {
    countdownTask?.cancel()
    countdownTask = nil
    dismissCountdownOverlay()
    cleanupAfterRecordingFailure()
  }

  private func dismissCountdownOverlay() {
    countdownOverlayWindow?.orderOut(nil)
    countdownOverlayWindow?.contentView = nil
    countdownOverlayWindow = nil
  }

  private func cleanupAfterRecordingFailure() {
    mouseClickMonitor?.stop()
    mouseClickMonitor = nil
    cursorMetadataRecorder?.stop()
    cursorMetadataRecorder = nil
    selectionCoordinator?.destroyAll()
    selectionCoordinator = nil
    windowSelectionCoordinator?.destroyOverlay()
    windowSelectionCoordinator = nil
    devicePreviewWindow?.close()
    devicePreviewWindow = nil
    deviceCapture?.stop()
    deviceCapture = nil
    captureTarget = nil
    transition(to: .idle)
  }

  func startRecording() async throws {
    switch state {
    case .selecting, .idle, .countdown:
      break
    default:
      throw CaptureError.invalidTransition(from: "\(state)", to: "recording")
    }

    if captureMode == .device, let capture = deviceCapture {
      let coordinator = RecordingCoordinator()
      self.recordingCoordinator = coordinator
      overlayView = nil

      let useCam = isCameraOn && options.selectedCamera != nil
      let useMic = isMicrophoneOn && options.selectedMicrophone != nil

      var existingWebcam: (WebcamCapture, VerifiedCamera)?
      if useCam, let webcam = persistentWebcam, let info = verifiedCameraInfo {
        existingWebcam = (webcam, info)
      }

      let startedAt = try await coordinator.startDeviceRecording(
        deviceCapture: capture,
        fps: options.fps,
        microphoneDeviceId: useMic ? options.selectedMicrophone?.id : nil,
        cameraDeviceId: useCam ? options.selectedCamera?.id : nil,
        cameraResolution: ConfigService.shared.cameraMaximumResolution,
        existingWebcam: existingWebcam,
        captureQuality: options.captureQuality,
        retinaCapture: options.retinaCapture
      )

      if existingWebcam == nil, useCam {
        let box = await coordinator.getWebcamCaptureSessionBox()
        if let camSession = box?.session {
          let previewWindow = WebcamPreviewWindow()
          previewWindow.show(captureSession: camSession)
          self.webcamPreviewWindow = previewWindow
        }
      }

      SoundEffect.startRecording.play()
      transition(to: .recording(startedAt: startedAt))
      return
    }

    guard let target = captureTarget else {
      throw CaptureError.noSelectionStored
    }

    let coordinator = RecordingCoordinator()
    self.recordingCoordinator = coordinator
    overlayView = nil

    let useCam = isCameraOn && options.selectedCamera != nil
    let useMic = isMicrophoneOn && options.selectedMicrophone != nil

    var existingWebcam: (WebcamCapture, VerifiedCamera)?
    if useCam, let webcam = persistentWebcam, let info = verifiedCameraInfo {
      existingWebcam = (webcam, info)
    }

    let metadataRecorder = CursorMetadataRecorder()
    self.cursorMetadataRecorder = metadataRecorder

    let startedAt = try await coordinator.startRecording(
      target: target,
      fps: options.fps,
      captureSystemAudio: options.captureSystemAudio,
      microphoneDeviceId: useMic ? options.selectedMicrophone?.id : nil,
      cameraDeviceId: useCam ? options.selectedCamera?.id : nil,
      cameraResolution: ConfigService.shared.cameraMaximumResolution,
      existingWebcam: existingWebcam,
      cursorMetadataRecorder: metadataRecorder,
      captureQuality: options.captureQuality,
      retinaCapture: options.retinaCapture
    )

    metadataRecorder.start()

    if existingWebcam == nil, useCam {
      let box = await coordinator.getWebcamCaptureSessionBox()
      if let camSession = box?.session {
        let previewWindow = WebcamPreviewWindow()
        previewWindow.show(captureSession: camSession)
        self.webcamPreviewWindow = previewWindow
      }
    }

    let monitor = MouseClickMonitor(metadataRecorder: metadataRecorder)
    monitor.start()
    mouseClickMonitor = monitor

    SoundEffect.startRecording.play()
    transition(to: .recording(startedAt: startedAt))
  }

  func stopRecording() async throws {
    switch state {
    case .recording, .paused:
      break
    default:
      throw CaptureError.invalidTransition(from: "\(state)", to: "processing")
    }

    mouseClickMonitor?.stop()
    mouseClickMonitor = nil
    cursorMetadataRecorder = nil

    SoundEffect.stopRecording.play()
    transition(to: .processing)
    selectionCoordinator?.destroyAll()
    selectionCoordinator = nil

    guard let result = try await recordingCoordinator?.stopRecordingRaw(keepWebcamAlive: false) else {
      recordingCoordinator = nil
      captureTarget = nil
      captureMode = .none
      stopCameraPreview()
      transition(to: .idle)
      showToolbar()
      return
    }

    recordingCoordinator = nil
    captureTarget = nil
    stopCameraPreview()
    devicePreviewWindow?.close()
    devicePreviewWindow = nil
    deviceCapture = nil

    let saveDir = FileManager.default.projectSaveDirectory()
    do {
      let project = try ReframedProject.create(from: result, fps: result.fps, captureMode: captureMode, in: saveDir)
      openEditor(project: project)
    } catch {
      logger.error("Failed to create project bundle: \(error)")
      openEditor(project: nil, result: result)
    }
  }

  private func openEditor(project: ReframedProject?, result: RecordingResult? = nil) {
    hideToolbar()
    transition(to: .editing)

    let editor = EditorWindow()
    editor.onSave = { [weak self, weak editor] url in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.lastRecordingURL = url
        self.logger.info("Editor save: \(url.path)")
        if let editor { self.removeEditor(editor) }
      }
    }
    editor.onCancel = { [weak self, weak editor] in
      MainActor.assumeIsolated {
        if let self, let editor { self.removeEditor(editor) }
      }
    }
    editor.onDelete = { [weak self, weak editor] in
      MainActor.assumeIsolated {
        if let self, let editor { self.removeEditor(editor) }
      }
    }
    if let project {
      editor.show(project: project)
    } else if let result {
      editor.show(result: result)
    }
    editorWindows.append(editor)
  }

  func openProject(at url: URL) {
    do {
      let project = try ReframedProject.open(at: url)
      openEditor(project: project)
    } catch {
      logger.error("Failed to open project: \(error)")
      showError("Failed to open project: \(error.localizedDescription)")
    }
  }

  private func removeEditor(_ editor: EditorWindow) {
    editorWindows.removeAll { $0 === editor }
    if editorWindows.isEmpty {
      captureMode = .none
      transition(to: .idle)
      showToolbar()
    }
  }

  func pauseRecording() {
    guard case .recording(let startedAt) = state else { return }
    let elapsed = Date().timeIntervalSince(startedAt)
    mouseClickMonitor?.stop()
    SoundEffect.pauseRecording.play()
    Task {
      await recordingCoordinator?.pause()
    }
    transition(to: .paused(elapsed: elapsed))
  }

  func resumeRecording() {
    guard case .paused(let elapsed) = state else { return }
    let resumedAt = Date().addingTimeInterval(-elapsed)
    mouseClickMonitor?.start()
    SoundEffect.resumeRecording.play()
    Task {
      await recordingCoordinator?.resume()
    }
    transition(to: .recording(startedAt: resumedAt))
  }

  func restartRecording() {
    countdownTask?.cancel()
    countdownTask = nil
    dismissCountdownOverlay()
    mouseClickMonitor?.stop()
    mouseClickMonitor = nil

    let savedTarget = captureTarget
    let savedMode = captureMode
    let keepWebcam = persistentWebcam != nil

    Task {
      selectionCoordinator?.destroyAll()
      selectionCoordinator = nil
      if !keepWebcam {
        webcamPreviewWindow?.close()
        webcamPreviewWindow = nil
      }
      for editor in editorWindows { editor.close() }
      editorWindows.removeAll()

      if let url = try? await recordingCoordinator?.stopRecording(keepWebcamAlive: keepWebcam) {
        try? FileManager.default.removeItem(at: url)
        logger.info("Discarded recording: \(url.path)")
      }
      recordingCoordinator = nil
      FileManager.default.cleanupTempDir()

      captureTarget = savedTarget
      captureMode = savedMode
      transition(to: .idle)

      guard savedTarget != nil else { return }

      if case .region(let sel) = savedTarget {
        let coordinator = SelectionCoordinator()
        selectionCoordinator = coordinator
        coordinator.showRecordingBorder(screenRect: sel.rect)
      } else if case .window(let win) = savedTarget {
        if let screen = NSScreen.main {
          let scFrame = win.frame
          let screenHeight = screen.frame.height
          let appKitRect = CGRect(
            x: scFrame.origin.x,
            y: screenHeight - scFrame.origin.y - scFrame.height,
            width: scFrame.width,
            height: scFrame.height
          )
          let coordinator = SelectionCoordinator()
          selectionCoordinator = coordinator
          coordinator.showRecordingBorder(screenRect: appKitRect)
        }
      }

      beginRecordingWithCountdown()
    }
  }

  func showError(_ message: String) {
    let alert = NSAlert()
    alert.messageText = "Recording Error"
    alert.informativeText = message
    alert.alertStyle = .critical
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }

  private func transition(to newState: CaptureState) {
    state = newState
    updateStatusIcon()

    switch newState {
    case .recording:
      if audioLevelTask == nil { startAudioLevelPolling() }
    case .paused:
      break
    default:
      stopAudioLevelPolling()
    }
  }

  private func updateStatusIcon() {
    let iconName: String =
      switch state {
      case .idle: "rectangle.dashed.badge.record"
      case .selecting: "rectangle.dashed"
      case .countdown: "timer"
      case .recording: "record.circle.fill"
      case .paused: "pause.circle.fill"
      case .processing: "gear"
      case .editing: "film"
      }
    statusItemButton?.image = NSImage(
      systemSymbolName: iconName,
      accessibilityDescription: "Reframed"
    )
  }

  private func showStartRecordingOverlay() {
    guard startRecordingWindow == nil else { return }
    guard let screen = NSScreen.main else { return }

    let window = StartRecordingWindow(screen: screen) { [weak self] in
      MainActor.assumeIsolated {
        self?.startRecordingFromOverlay()
      }
    }
    startRecordingWindow = window
    window.orderFrontRegardless()
    toolbarWindow?.makeKeyAndOrderFront(nil)
  }

  private func hideStartRecordingOverlay() {
    startRecordingWindow?.orderOut(nil)
    startRecordingWindow?.contentView = nil
    startRecordingWindow = nil
  }

  private func startRecordingFromOverlay() {
    hideStartRecordingOverlay()
    recordEntireScreen()
  }

  func startDeviceRecordingWith(deviceId: String) {
    guard case .idle = state else { return }

    let devices = DeviceDiscovery.shared.availableDevices
    guard let device = devices.first(where: { $0.id == deviceId }) else {
      showError(CaptureError.deviceNotFound.localizedDescription)
      return
    }

    let capture = DeviceCapture()
    deviceCapture = capture

    Task {
      do {
        let info = try await capture.startAndVerify(deviceId: device.id)
        guard captureMode == .device else {
          capture.stop()
          deviceCapture = nil
          return
        }

        if let session = capture.captureSession {
          let previewWindow = DevicePreviewWindow()
          previewWindow.show(captureSession: session, deviceName: device.name)
          devicePreviewWindow = previewWindow
        }

        logger.info("Device preview started: \(device.name) at \(info.width)x\(info.height)")
        beginRecordingWithCountdown()
      } catch {
        logger.error("Device recording failed: \(error)")
        deviceCapture?.stop()
        deviceCapture = nil
        showError(error.localizedDescription)
      }
    }
  }

  private func recordEntireScreen() {
    guard Permissions.hasScreenRecordingPermission else {
      Permissions.requestScreenRecordingPermission()
      return
    }

    guard let screen = NSScreen.main else { return }
    let selection = SelectionRect(rect: screen.frame, displayID: screen.displayID)
    captureTarget = .region(selection)

    let coordinator = SelectionCoordinator()
    selectionCoordinator = coordinator
    coordinator.showRecordingBorder(screenRect: screen.frame)

    beginRecordingWithCountdown()
  }
}
