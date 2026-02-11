import AppKit
import Foundation
import Logging

@MainActor
final class ConfigService {
  static let shared = ConfigService()

  private let logger = Logger(label: "eu.jankuri.frame.config")
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

  var showFloatingThumbnail: Bool {
    get { data.showFloatingThumbnail }
    set { data.showFloatingThumbnail = newValue; save() }
  }

  var rememberLastSelection: Bool {
    get { data.rememberLastSelection }
    set { data.rememberLastSelection = newValue; save() }
  }

  var showMouseClicks: Bool {
    get { data.showMouseClicks }
    set { data.showMouseClicks = newValue; save() }
  }

  var fps: Int {
    get { data.fps }
    set { data.fps = newValue; save() }
  }

  var captureSystemAudio: Bool {
    get { data.captureSystemAudio }
    set { data.captureSystemAudio = newValue; save() }
  }

  var cameraDeviceId: String? {
    get { data.cameraDeviceId }
    set { data.cameraDeviceId = newValue; save() }
  }

  var projectFolder: String {
    get { data.projectFolder }
    set { data.projectFolder = newValue; save() }
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
    let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".frame", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    fileURL = dir.appendingPathComponent("frame.json")
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
}

private struct ConfigData: Codable {
  var outputFolder: String = "~/Movies/Frame"
  var timerDelay: Int = 0
  var audioDeviceId: String? = nil
  var showFloatingThumbnail: Bool = true
  var rememberLastSelection: Bool = true
  var showMouseClicks: Bool = false
  var fps: Int = 60
  var captureSystemAudio: Bool = false
  var cameraDeviceId: String? = nil
  var projectFolder: String = "~/Frame"
  var appearance: String = "system"
}
