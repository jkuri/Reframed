import AppKit
import Foundation
import ScreenCaptureKit

@MainActor
extension SessionState {
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
    if let existing = toolbarWindow {
      existing.orderFrontRegardless()
      return
    }

    let window = CaptureToolbarWindow(session: self) { [weak self] in
      MainActor.assumeIsolated {
        self?.hideToolbar()
      }
    }
    toolbarWindow = window
    window.orderFrontRegardless()
  }

  func hideToolbar() {
    hideStartRecordingOverlay()
    toolbarWindow?.orderOut(nil)
    toolbarWindow?.contentView = nil
    toolbarWindow = nil
  }

  func showStartRecordingOverlay() {
    guard startRecordingWindows.isEmpty else { return }
    guard !NSScreen.screens.isEmpty else { return }

    let screens = NSScreen.screens
    for (index, screen) in screens.enumerated() {
      let window = StartRecordingWindow(
        screen: screen,
        delay: options.timerDelay.rawValue,
        screenIndex: index + 1,
        totalScreens: screens.count,
        onCountdownStart: { [weak self] _ in
          MainActor.assumeIsolated {
            self?.toolbarWindow?.orderOut(nil)
          }
        },
        onCancel: { [weak self] in
          MainActor.assumeIsolated {
            self?.cancelSelection()
          }
        },
        onStart: { [weak self] screen in
          MainActor.assumeIsolated {
            self?.startRecordingFromOverlay(screen: screen)
          }
        }
      )
      startRecordingWindows.append(window)
      window.orderFrontRegardless()
    }
    startRecordingWindows.first?.makeKeyAndOrderFront(nil)
  }

  func hideStartRecordingOverlay() {
    for window in startRecordingWindows {
      window.orderOut(nil)
      window.contentView = nil
    }
    startRecordingWindows.removeAll()
  }

  func startRecordingFromOverlay(screen: NSScreen) {
    hideStartRecordingOverlay()
    recordEntireScreen(screen: screen)
  }

  func cleanupCoordinators() {
    selectionCoordinator?.destroyAll()
    selectionCoordinator = nil
    windowSelectionCoordinator?.destroyOverlay()
    windowSelectionCoordinator = nil
  }

  func updateStatusIcon() {
    let isExporting = editorWindows.contains { $0.isExporting }
    let needsPulse =
      isExporting
      || {
        if case .processing = state { return true }; return false
      }()

    if needsPulse {
      startProcessingPulse()
      return
    }

    stopProcessingPulse()
    let iconState: MenuBarIcon.State =
      switch state {
      case .idle: .idle
      case .selecting: .selecting
      case .countdown: .countdown
      case .recording: .recording
      case .paused: .paused
      case .processing: .processing
      case .editing: .editing
      }
    menuBarIconState = iconState
    statusItemButton?.image = MenuBarIcon.makeImage(for: iconState)
  }

  private func startProcessingPulse() {
    guard processingPulseTimer == nil else { return }
    processingPulseOn = true
    menuBarIconState = .processingPulse
    statusItemButton?.image = MenuBarIcon.makeImage(for: .processingPulse)
    processingPulseTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.processingPulseOn.toggle()
        let pulseState: MenuBarIcon.State = self.processingPulseOn ? .processingPulse : .processing
        self.menuBarIconState = pulseState
        self.statusItemButton?.image = MenuBarIcon.makeImage(for: pulseState)
      }
    }
  }

  private func stopProcessingPulse() {
    processingPulseTimer?.invalidate()
    processingPulseTimer = nil
    processingPulseOn = false
  }

  func showError(_ message: String) {
    let alert = NSAlert()
    alert.messageText = "Recording Error"
    alert.informativeText = message
    alert.alertStyle = .critical
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }

  func focusWindow(pid: pid_t, frame: CGRect) {
    let axApp = AXUIElementCreateApplication(pid)
    var windowsRef: CFTypeRef?
    AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef)
    if let windows = windowsRef as? [AXUIElement] {
      for window in windows {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef)
        AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)

        var pos = CGPoint.zero
        var size = CGSize.zero
        if let posRef = positionRef, CFGetTypeID(posRef) == AXValueGetTypeID() {
          AXValueGetValue(posRef as! AXValue, .cgPoint, &pos)
        }
        if let sRef = sizeRef, CFGetTypeID(sRef) == AXValueGetTypeID() {
          AXValueGetValue(sRef as! AXValue, .cgSize, &size)
        }

        if abs(pos.x - frame.origin.x) < 20
          && abs(pos.y - frame.origin.y) < 20
          && abs(size.width - frame.width) < 20
          && abs(size.height - frame.height) < 20
        {
          AXUIElementPerformAction(window, kAXRaiseAction as CFString)
          NSRunningApplication(processIdentifier: pid)?.activate()
          return
        }
      }
    }
    NSRunningApplication(processIdentifier: pid)?.activate()
  }
}
