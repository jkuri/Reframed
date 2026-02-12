import Foundation

enum CaptureState: Sendable, Equatable {
  case idle
  case selecting
  case countdown(remaining: Int)
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
  case microphoneNotFound
  case cameraNotFound
  case cameraStreamFailed
  case microphoneStreamFailed
  case deviceNotFound
  case deviceStreamFailed

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
    case .microphoneNotFound:
      return "Could not find the selected microphone"
    case .cameraNotFound:
      return "Could not find the selected camera"
    case .cameraStreamFailed:
      return "Camera failed to start streaming. Make sure no other app is using the camera."
    case .microphoneStreamFailed:
      return "Microphone failed to start streaming. Make sure no other app is using the microphone."
    case .deviceNotFound:
      return "No iOS device found. Connect an iPhone or iPad via USB and trust this Mac."
    case .deviceStreamFailed:
      return "Device failed to start streaming. Make sure the device is unlocked and trusted."
    }
  }
}
