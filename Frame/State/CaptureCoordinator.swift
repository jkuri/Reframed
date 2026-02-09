import Foundation
import Logging
import SwiftUI

@MainActor
@Observable
final class StateProjection {
  var state: CaptureState = .idle
  var lastRecordingURL: URL?
}

actor CaptureCoordinator {
  @MainActor let ui = StateProjection()

  private let logger = Logger(label: "com.frame.coordinator")
  private var state: CaptureState = .idle {
    didSet {
      let newState = state
      logger.info("State: \(String(describing: newState))")
      Task { @MainActor in ui.state = newState }
    }
  }

  private var storedSelection: SelectionRect?
  private var recordingCoordinator: RecordingCoordinator?

  // MARK: - Selection

  func beginSelection() async throws {
    guard case .idle = state else {
      throw CaptureError.invalidTransition(from: "\(state)", to: "selecting")
    }

    guard Permissions.hasScreenRecordingPermission else {
      Permissions.requestScreenRecordingPermission()
      throw CaptureError.permissionDenied
    }

    state = .selecting
    storedSelection = nil

    let result: SelectionRect? = await withCheckedContinuation { continuation in
      Task { @MainActor in
        let coordinator = SelectionCoordinator()
        coordinator.beginSelection { rect in
          continuation.resume(returning: rect)
        }
      }
    }

    if let result {
      storedSelection = result
      state = .idle
      logger.info("Selection confirmed: \(result.rect)")
      try await startRecording()
    } else {
      state = .idle
      logger.info("Selection cancelled")
    }
  }

  func cancelSelection() {
    guard case .selecting = state else { return }
    state = .idle
    storedSelection = nil
  }

  // MARK: - Recording

  func startRecording() async throws {
    guard case .idle = state else {
      throw CaptureError.invalidTransition(from: "\(state)", to: "recording")
    }
    guard let selection = storedSelection else {
      throw CaptureError.noSelectionStored
    }

    let coordinator = RecordingCoordinator()
    self.recordingCoordinator = coordinator

    let startedAt = try await coordinator.startRecording(selection: selection)
    state = .recording(startedAt: startedAt)
  }

  func stopRecording() async throws {
    switch state {
    case .recording, .paused:
      break
    default:
      throw CaptureError.invalidTransition(from: "\(state)", to: "processing")
    }

    state = .processing

    if let url = try await recordingCoordinator?.stopRecording() {
      Task { @MainActor in ui.lastRecordingURL = url }
      logger.info("Recording saved to \(url.path)")
    }

    recordingCoordinator = nil
    storedSelection = nil
    state = .idle
  }

  func pauseRecording() {
    guard case .recording(let startedAt) = state else { return }
    let elapsed = Date().timeIntervalSince(startedAt)
    state = .paused(elapsed: elapsed)
  }

  func resumeRecording() {
    guard case .paused(let elapsed) = state else { return }
    let resumedAt = Date().addingTimeInterval(-elapsed)
    state = .recording(startedAt: resumedAt)
  }
}
