import AppKit

@MainActor
enum SoundEffect {
  case startRecording
  case stopRecording
  case pauseRecording
  case resumeRecording

  func play() {
    guard let sound = NSSound(named: soundName) else { return }
    sound.volume = volume
    sound.play()
  }

  private var soundName: NSSound.Name {
    switch self {
    case .startRecording: return "Blow"
    case .stopRecording: return "Glass"
    case .pauseRecording: return "Pop"
    case .resumeRecording: return "Tink"
    }
  }

  private var volume: Float {
    switch self {
    case .startRecording: return 0.4
    case .stopRecording: return 0.35
    case .pauseRecording: return 0.3
    case .resumeRecording: return 0.3
    }
  }
}
