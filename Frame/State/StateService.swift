import Foundation
import Logging

@MainActor
final class StateService {
  static let shared = StateService()

  private let logger = Logger(label: "eu.jankuri.frame.state-service")
  private let fileURL: URL
  private var data: StateData

  var lastCaptureMode: CaptureMode {
    get {
      CaptureMode(rawValue: data.lastCaptureMode) ?? .none
    }
    set {
      data.lastCaptureMode = newValue.rawValue
      save()
    }
  }

  var lastSelectionRect: CGRect? {
    get {
      guard let r = data.lastSelectionRect else { return nil }
      return CGRect(x: r.x, y: r.y, width: r.width, height: r.height)
    }
    set {
      if let r = newValue {
        data.lastSelectionRect = RectData(x: r.origin.x, y: r.origin.y, width: r.width, height: r.height)
      } else {
        data.lastSelectionRect = nil
      }
      save()
    }
  }

  var lastDisplayID: UInt32 {
    get { data.lastDisplayID }
    set { data.lastDisplayID = newValue; save() }
  }

  var lastRecordingPath: String? {
    get { data.lastRecordingPath }
    set { data.lastRecordingPath = newValue; save() }
  }

  private init() {
    let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".frame", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    fileURL = dir.appendingPathComponent("state.json")
    data = StateData()
    load()
  }

  private func load() {
    guard let raw = try? Data(contentsOf: fileURL),
      let decoded = try? JSONDecoder().decode(StateData.self, from: raw)
    else {
      logger.info("No state found, using defaults")
      return
    }
    data = decoded
  }

  func save() {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let raw = try? encoder.encode(data) else { return }
    try? raw.write(to: fileURL, options: .atomic)
  }
}

private struct RectData: Codable {
  var x: Double
  var y: Double
  var width: Double
  var height: Double
}

private struct StateData: Codable {
  var lastCaptureMode: String = "none"
  var lastSelectionRect: RectData? = nil
  var lastDisplayID: UInt32 = 1
  var lastRecordingPath: String? = nil
}
