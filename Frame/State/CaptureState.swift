import Foundation

enum CaptureState: Sendable, Equatable {
  case idle
  case selecting
  case recording(startedAt: Date)
  case paused(elapsed: TimeInterval)
  case processing
  case editing
}

enum CaptureError: LocalizedError {
  case invalidTransition(from: String, to: String)
  case noSelectionStored
  case displayNotFound
  case permissionDenied
  case recordingFailed(String)

  var errorDescription: String? {
    switch self {
    case .invalidTransition(let from, let to):
      return "Invalid state transition from \(from) to \(to)"
    case .noSelectionStored:
      return "No screen region has been selected"
    case .displayNotFound:
      return "Could not find the target display"
    case .permissionDenied:
      return "Screen recording permission is required"
    case .recordingFailed(let reason):
      return "Recording failed: \(reason)"
    }
  }
}
