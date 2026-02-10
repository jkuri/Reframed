import AVFoundation
import SwiftUI

enum TimerDelay: Int, CaseIterable, Sendable {
  case none = 0
  case fiveSeconds = 5
  case tenSeconds = 10

  var label: String {
    switch self {
    case .none: "None"
    case .fiveSeconds: "5 Seconds"
    case .tenSeconds: "10 Seconds"
    }
  }
}

struct AudioDevice: Identifiable, Hashable, Sendable {
  let id: String
  let name: String
}

@MainActor
@Observable
final class RecordingOptions {
  var timerDelay: TimerDelay = .none
  var selectedMicrophone: AudioDevice?
  var showFloatingThumbnail: Bool = true
  var rememberLastSelection: Bool = true
  var showMouseClicks: Bool = false

  var availableMicrophones: [AudioDevice] {
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.microphone],
      mediaType: .audio,
      position: .unspecified
    )
    return discovery.devices.map { AudioDevice(id: $0.uniqueID, name: $0.localizedName) }
  }
}
