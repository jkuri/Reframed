import AppKit
import Foundation
import Logging
import ScreenCaptureKit
import SwiftUI

@MainActor
@Observable
final class SessionState {
  var state: CaptureState = .idle
  var lastRecordingURL: URL?
  var captureMode: CaptureMode = .none
  var errorMessage: String?
  let options = RecordingOptions()

  weak var statusItemButton: NSStatusBarButton?

  private let logger = Logger(label: "eu.jankuri.frame.session")
  private var selectionCoordinator: SelectionCoordinator?
  private var windowSelectionCoordinator: WindowSelectionCoordinator?
  private var recordingCoordinator: RecordingCoordinator?
  private var captureTarget: CaptureTarget?
  private var toolbarWindow: CaptureToolbarWindow?
  private var backdropWindow: ToolbarBackdropWindow?
  private var startRecordingWindow: StartRecordingWindow?
  private var editorWindows: [EditorWindow] = []
  private var webcamPreviewWindow: WebcamPreviewWindow?
  private var countdownOverlayWindow: CountdownOverlayWindow?
  private var countdownTask: Task<Void, Never>?

  weak var overlayView: SelectionOverlayView?

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

    let backdrop = ToolbarBackdropWindow { [weak self] in
      MainActor.assumeIsolated {
        guard let self else { return }
        switch self.state {
        case .countdown, .recording, .paused, .processing, .editing:
          return
        default:
          self.hideToolbar()
        }
      }
    }
    backdropWindow = backdrop
    backdrop.orderFrontRegardless()

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
    dismissBackdrop()
  }

  private func dismissBackdrop() {
    backdropWindow?.orderOut(nil)
    backdropWindow?.contentView = nil
    backdropWindow = nil
  }

  func selectMode(_ mode: CaptureMode) {
    captureMode = mode
    StateService.shared.lastCaptureMode = mode
    hideStartRecordingOverlay()

    switch mode {
    case .none:
      break
    case .entireScreen:
      showStartRecordingOverlay()
    case .selectedWindow:
      dismissBackdrop()
      startWindowSelection()
    case .selectedArea:
      dismissBackdrop()
      do {
        try beginSelection()
      } catch {
        logger.error("Failed to begin selection: \(error)")
      }
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
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        MainActor.assumeIsolated {
          self?.overlayView?.applyExternalRect(savedRect)
          self?.captureTarget = .region(SelectionRect(rect: savedRect, displayID: displayID))
        }
      }
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
    selectionCoordinator?.destroyAll()
    selectionCoordinator = nil
    windowSelectionCoordinator?.destroyOverlay()
    windowSelectionCoordinator = nil
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
    guard let target = captureTarget else {
      throw CaptureError.noSelectionStored
    }

    let coordinator = RecordingCoordinator()
    self.recordingCoordinator = coordinator
    overlayView = nil

    let startedAt = try await coordinator.startRecording(
      target: target,
      fps: options.fps,
      captureSystemAudio: options.captureSystemAudio,
      microphoneDeviceId: options.selectedMicrophone?.id,
      cameraDeviceId: options.selectedCamera?.id
    )

    if options.selectedCamera != nil {
      let box = await coordinator.getWebcamCaptureSessionBox()
      if let camSession = box?.session {
        let previewWindow = WebcamPreviewWindow()
        previewWindow.show(captureSession: camSession)
        self.webcamPreviewWindow = previewWindow
      }
    }

    transition(to: .recording(startedAt: startedAt))
  }

  func stopRecording() async throws {
    switch state {
    case .recording, .paused:
      break
    default:
      throw CaptureError.invalidTransition(from: "\(state)", to: "processing")
    }

    transition(to: .processing)
    selectionCoordinator?.destroyAll()
    selectionCoordinator = nil
    webcamPreviewWindow?.close()
    webcamPreviewWindow = nil

    guard let result = try await recordingCoordinator?.stopRecordingRaw() else {
      recordingCoordinator = nil
      captureTarget = nil
      captureMode = .none
      transition(to: .idle)
      showToolbar()
      return
    }

    recordingCoordinator = nil
    captureTarget = nil

    let saveDir = FileManager.default.projectSaveDirectory()
    do {
      let project = try FrameProject.create(from: result, fps: result.fps, in: saveDir)
      openEditor(project: project)
    } catch {
      logger.error("Failed to create project bundle: \(error)")
      openEditor(project: nil, result: result)
    }
  }

  private func openEditor(project: FrameProject?, result: RecordingResult? = nil) {
    hideToolbar()
    transition(to: .editing)

    let editor = EditorWindow()
    editor.onSave = { [weak self, weak editor] url in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.lastRecordingURL = url
        StateService.shared.lastRecordingPath = url.path
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
      let project = try FrameProject.open(at: url)
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

  func openSettings() {
    hideToolbar()
    SettingsWindow.shared.onClose = { [weak self] in
      MainActor.assumeIsolated {
        guard let self else { return }
        if case .editing = self.state {
          self.editorWindows.last?.bringToFront()
        } else {
          self.showToolbar()
        }
      }
    }
    SettingsWindow.shared.show()
  }

  func pauseRecording() {
    guard case .recording(let startedAt) = state else { return }
    let elapsed = Date().timeIntervalSince(startedAt)
    Task {
      await recordingCoordinator?.pause()
    }
    transition(to: .paused(elapsed: elapsed))
  }

  func resumeRecording() {
    guard case .paused(let elapsed) = state else { return }
    let resumedAt = Date().addingTimeInterval(-elapsed)
    Task {
      await recordingCoordinator?.resume()
    }
    transition(to: .recording(startedAt: resumedAt))
  }

  func restartRecording() {
    countdownTask?.cancel()
    countdownTask = nil
    dismissCountdownOverlay()

    Task {
      selectionCoordinator?.destroyAll()
      selectionCoordinator = nil
      webcamPreviewWindow?.close()
      webcamPreviewWindow = nil
      for editor in editorWindows { editor.close() }
      editorWindows.removeAll()

      if let url = try? await recordingCoordinator?.stopRecording() {
        try? FileManager.default.removeItem(at: url)
        logger.info("Discarded recording: \(url.path)")
      }
      recordingCoordinator = nil
      captureTarget = nil
      captureMode = .none
      FileManager.default.cleanupTempDir()
      transition(to: .idle)
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
      accessibilityDescription: "Frame"
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
    dismissBackdrop()
    recordEntireScreen()
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
