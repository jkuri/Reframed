import AppKit
import Foundation

@MainActor
extension SessionState {
  func startWindowTracking(windowID: CGWindowID) {
    windowPositionObserver = WindowPositionObserver(
      windowID: windowID,
      onDisappeared: { [weak self] in
        guard let self else { return }
        Task { @MainActor in await self.handleStreamError() }
      }
    ) { [weak self] rect in
      self?.selectionCoordinator?.updateRecordingBorder(screenRect: rect)
      if let recorder = self?.cursorMetadataRecorder {
        let sckOrigin = CGPoint(
          x: rect.origin.x,
          y: NSScreen.primaryScreenHeight - rect.origin.y - rect.height
        )
        recorder.updateCaptureOrigin(sckOrigin)
      }
    }
  }

  func stopWindowTracking() {
    windowPositionObserver?.stop()
    windowPositionObserver = nil
  }
}
