import AppKit
import Foundation
import ScreenCaptureKit

@MainActor
extension SessionState {
  func selectMode(_ mode: CaptureMode) {
    captureMode = mode
    hideStartRecordingOverlay()

    switch mode {
    case .none:
      break
    case .entireScreen:
      hideToolbar()
      showStartRecordingOverlay()
    case .selectedWindow:
      hideToolbar()
      startWindowSelection()
    case .selectedArea:
      hideToolbar()
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
      coordinator.restoreSelection(savedRect, displayID: displayID, session: self)
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
    let screenHeight = NSScreen.primaryScreenHeight
    let appKitRect = CGRect(
      x: scFrame.origin.x,
      y: screenHeight - scFrame.origin.y - scFrame.height,
      width: scFrame.width,
      height: scFrame.height
    )
    let coordinator = SelectionCoordinator()
    selectionCoordinator = coordinator
    coordinator.showRecordingBorder(screenRect: appKitRect)

    beginRecordingWithCountdown()
  }

  func updateWindowHighlight(_ window: SCWindow?) {
    windowSelectionCoordinator?.highlight(window: window)
  }

  func cancelSelection() {
    cleanupCoordinators()
    overlayView = nil
    hideStartRecordingOverlay()
    devicePreviewWindow?.close()
    devicePreviewWindow = nil
    deviceCapture?.stop()
    deviceCapture = nil
    transition(to: .idle)
    showToolbar()
    logger.info("Selection cancelled")
  }

  func updateOverlaySelection(_ rect: CGRect) {
    overlayView?.applyExternalRect(rect)
  }
}
