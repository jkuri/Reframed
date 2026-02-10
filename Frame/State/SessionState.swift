import AppKit
import Foundation
import Logging
import SwiftUI

@MainActor
@Observable
final class SessionState {
  var state: CaptureState = .idle
  var lastRecordingURL: URL?
  var captureMode: CaptureMode = .none
  let options = RecordingOptions()

  weak var statusItemButton: NSStatusBarButton?
  var onBecomeIdle: (() -> Void)?

  private let logger = Logger(label: "eu.jankuri.frame.session")
  private var selectionCoordinator: SelectionCoordinator?
  private var recordingCoordinator: RecordingCoordinator?
  private var storedSelection: SelectionRect?
  private var toolbarWindow: CaptureToolbarWindow?
  private var backdropWindow: ToolbarBackdropWindow?
  private var startRecordingWindow: StartRecordingWindow?

  weak var overlayView: SelectionOverlayView?

  func toggleToolbar() {
    if toolbarWindow != nil {
      hideToolbar()
    } else {
      showToolbar()
    }
  }

  func showToolbar() {
    guard toolbarWindow == nil else { return }

    let backdrop = ToolbarBackdropWindow { [weak self] in
      MainActor.assumeIsolated {
        self?.hideToolbar()
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
    backdropWindow?.orderOut(nil)
    backdropWindow?.contentView = nil
    backdropWindow = nil
  }

  func selectMode(_ mode: CaptureMode) {
    captureMode = mode
    hideStartRecordingOverlay()

    switch mode {
    case .none:
      break
    case .entireScreen, .selectedWindow:
      showStartRecordingOverlay()
    case .selectedArea:
      hideToolbar()
      do {
        try beginSelection()
      } catch {
        logger.error("Failed to begin selection: \(error)")
      }
    }
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
    storedSelection = nil

    let coordinator = SelectionCoordinator()
    selectionCoordinator = coordinator
    coordinator.beginSelection(session: self)
  }

  func confirmSelection(_ selection: SelectionRect) {
    selectionCoordinator?.destroyOverlay()
    selectionCoordinator?.showRecordingBorder(screenRect: selection.rect)
    storedSelection = selection
    logger.info("Selection confirmed: \(selection.rect)")

    Task {
      do {
        try await startRecording()
      } catch {
        logger.error("Failed to start recording: \(error)")
      }
    }
  }

  func cancelSelection() {
    selectionCoordinator?.destroyAll()
    selectionCoordinator = nil
    overlayView = nil
    transition(to: .idle)
    logger.info("Selection cancelled")
  }

  func updateOverlaySelection(_ rect: CGRect) {
    overlayView?.applyExternalRect(rect)
  }

  func startRecording() async throws {
    switch state {
    case .selecting, .idle:
      break
    default:
      throw CaptureError.invalidTransition(from: "\(state)", to: "recording")
    }
    guard let selection = storedSelection else {
      throw CaptureError.noSelectionStored
    }

    let coordinator = RecordingCoordinator()
    self.recordingCoordinator = coordinator
    overlayView = nil

    let startedAt = try await coordinator.startRecording(selection: selection)
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

    if let url = try await recordingCoordinator?.stopRecording() {
      lastRecordingURL = url
      logger.info("Recording saved to \(url.path)")
    }

    recordingCoordinator = nil
    storedSelection = nil
    transition(to: .idle)
  }

  func pauseRecording() {
    guard case .recording(let startedAt) = state else { return }
    let elapsed = Date().timeIntervalSince(startedAt)
    transition(to: .paused(elapsed: elapsed))
  }

  func resumeRecording() {
    guard case .paused(let elapsed) = state else { return }
    let resumedAt = Date().addingTimeInterval(-elapsed)
    transition(to: .recording(startedAt: resumedAt))
  }

  private func transition(to newState: CaptureState) {
    state = newState
    updateStatusIcon()
    if newState == .idle {
      onBecomeIdle?()
    }
  }

  private func updateStatusIcon() {
    let iconName: String = switch state {
    case .idle: "rectangle.dashed.badge.record"
    case .selecting: "rectangle.dashed"
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
    let window = StartRecordingWindow { [weak self] in
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
    hideToolbar()
    recordEntireScreen()
  }

  private func recordEntireScreen() {
    guard Permissions.hasScreenRecordingPermission else {
      Permissions.requestScreenRecordingPermission()
      return
    }

    guard let screen = NSScreen.main else { return }
    let selection = SelectionRect(rect: screen.frame, displayID: screen.displayID)
    storedSelection = selection

    let coordinator = SelectionCoordinator()
    selectionCoordinator = coordinator
    coordinator.showRecordingBorder(screenRect: screen.frame)

    Task {
      do {
        try await startRecording()
      } catch {
        logger.error("Failed to start recording: \(error)")
      }
    }
  }
}
