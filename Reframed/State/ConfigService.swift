import AppKit
import Foundation
import Logging

@MainActor
final class ConfigService {
  static let shared = ConfigService()

  private let logger = Logger(label: "eu.jankuri.reframed.config")
  private let fileURL: URL
  private var data: ConfigData

  var outputFolder: String {
    get { data.outputFolder }
    set { data.outputFolder = newValue; save() }
  }

  var timerDelay: Int {
    get { data.timerDelay }
    set { data.timerDelay = newValue; save() }
  }

  var audioDeviceId: String? {
    get { data.audioDeviceId }
    set { data.audioDeviceId = newValue; save() }
  }

  var rememberLastSelection: Bool {
    get { data.rememberLastSelection }
    set { data.rememberLastSelection = newValue; save() }
  }

  var fps: Int {
    get { data.fps }
    set { data.fps = newValue; save() }
  }

  var captureSystemAudio: Bool {
    get { data.captureSystemAudio }
    set { data.captureSystemAudio = newValue; save() }
  }

  var captureQuality: String {
    get { data.captureQuality }
    set { data.captureQuality = newValue; save() }
  }

  var cameraDeviceId: String? {
    get { data.cameraDeviceId }
    set { data.cameraDeviceId = newValue; save() }
  }

  var cameraMaximumResolution: String {
    get { data.cameraMaximumResolution }
    set { data.cameraMaximumResolution = newValue; save() }
  }

  var projectFolder: String {
    get { data.projectFolder }
    set { data.projectFolder = newValue; save() }
  }

  var retinaCapture: Bool {
    get { data.retinaCapture }
    set { data.retinaCapture = newValue; save() }
  }

  var appearance: String {
    get { data.appearance }
    set { data.appearance = newValue; save(); applyAppearance() }
  }

  func applyAppearance() {
    switch data.appearance {
    case "light":
      NSApp.appearance = NSAppearance(named: .aqua)
    case "dark":
      NSApp.appearance = NSAppearance(named: .darkAqua)
    default:
      NSApp.appearance = nil
    }
  }

  private init() {
    let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".reframed", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    fileURL = dir.appendingPathComponent("reframed.json")
    data = ConfigData()
    load()
  }

  private func load() {
    guard let raw = try? Data(contentsOf: fileURL),
      let decoded = try? JSONDecoder().decode(ConfigData.self, from: raw)
    else {
      logger.info("No config found, using defaults")
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

  func shortcut(for action: ShortcutAction) -> KeyboardShortcut {
    data.shortcuts[action.rawValue] ?? action.defaultShortcut
  }

  func setShortcut(_ shortcut: KeyboardShortcut, for action: ShortcutAction) {
    data.shortcuts[action.rawValue] = shortcut
    save()
  }

  func resetShortcut(for action: ShortcutAction) {
    data.shortcuts.removeValue(forKey: action.rawValue)
    save()
  }

  func resetAllShortcuts() {
    data.shortcuts.removeAll()
    save()
  }
}

private struct ConfigData: Codable {
  var outputFolder: String = "~/Movies/Reframe"
  var timerDelay: Int = 3
  var audioDeviceId: String? = nil
  var rememberLastSelection: Bool = true
  var fps: Int = 60
  var captureQuality: String = "standard"
  var captureSystemAudio: Bool = false
  var cameraDeviceId: String? = nil
  var cameraMaximumResolution: String = "1080p"
  var projectFolder: String = "~/Reframed"
  var retinaCapture: Bool = false
  var appearance: String = "system"
  var shortcuts: [String: KeyboardShortcut] = [:]
}
