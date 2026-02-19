import AVFoundation
import SwiftUI

enum CaptureQuality: String, CaseIterable, Sendable, Codable {
  case standard
  case high
  case veryHigh

  var label: String {
    switch self {
    case .standard: "Standard"
    case .high: "High"
    case .veryHigh: "Very High"
    }
  }

  var isProRes: Bool {
    self == .high || self == .veryHigh
  }
}

enum TimerDelay: Int, CaseIterable, Sendable {
  case none = 0
  case threeSeconds = 3
  case fiveSeconds = 5
  case tenSeconds = 10

  var label: String {
    switch self {
    case .none: "None"
    case .threeSeconds: "3 Seconds"
    case .fiveSeconds: "5 Seconds"
    case .tenSeconds: "10 Seconds"
    }
  }
}

struct AudioDevice: Identifiable, Hashable, Sendable {
  let id: String
  let name: String
}

struct CaptureDevice: Identifiable, Hashable, Sendable {
  let id: String
  let name: String
}

@MainActor
@Observable
final class RecordingOptions {
  var timerDelay: TimerDelay {
    didSet { ConfigService.shared.timerDelay = timerDelay.rawValue }
  }

  var selectedMicrophone: AudioDevice? {
    didSet { ConfigService.shared.audioDeviceId = selectedMicrophone?.id }
  }

  var rememberLastSelection: Bool {
    didSet { ConfigService.shared.rememberLastSelection = rememberLastSelection }
  }

  var fps: Int {
    didSet { ConfigService.shared.fps = fps }
  }

  var captureQuality: CaptureQuality {
    didSet { ConfigService.shared.captureQuality = captureQuality.rawValue }
  }

  var captureSystemAudio: Bool {
    didSet { ConfigService.shared.captureSystemAudio = captureSystemAudio }
  }

  var retinaCapture: Bool {
    didSet { ConfigService.shared.retinaCapture = retinaCapture }
  }

  var selectedCamera: CaptureDevice? {
    didSet { ConfigService.shared.cameraDeviceId = selectedCamera?.id }
  }

  var availableCameras: [CaptureDevice] {
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera, .external],
      mediaType: .video,
      position: .unspecified
    )
    return discovery.devices.map { CaptureDevice(id: $0.uniqueID, name: $0.localizedName) }
  }

  var availableMicrophones: [AudioDevice] {
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.microphone],
      mediaType: .audio,
      position: .unspecified
    )
    return discovery.devices
      .filter { !$0.uniqueID.contains("CADefaultDeviceAggregate") }
      .map { AudioDevice(id: $0.uniqueID, name: $0.localizedName) }
  }

  init() {
    let config = ConfigService.shared
    timerDelay = TimerDelay(rawValue: config.timerDelay) ?? .none
    rememberLastSelection = config.rememberLastSelection
    fps = config.fps
    captureQuality = CaptureQuality(rawValue: config.captureQuality) ?? .standard
    captureSystemAudio = config.captureSystemAudio
    retinaCapture = config.retinaCapture

    let savedDeviceId = config.audioDeviceId
    if let deviceId = savedDeviceId {
      let discovery = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.microphone],
        mediaType: .audio,
        position: .unspecified
      )
      selectedMicrophone = discovery.devices
        .first { $0.uniqueID == deviceId }
        .map { AudioDevice(id: $0.uniqueID, name: $0.localizedName) }
    } else {
      selectedMicrophone = nil
    }

    if let cameraId = config.cameraDeviceId {
      let discovery = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera, .external],
        mediaType: .video,
        position: .unspecified
      )
      selectedCamera = discovery.devices
        .first { $0.uniqueID == cameraId }
        .map { CaptureDevice(id: $0.uniqueID, name: $0.localizedName) }
    } else {
      selectedCamera = nil
    }
  }
}
