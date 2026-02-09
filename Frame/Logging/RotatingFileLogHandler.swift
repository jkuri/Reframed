import Foundation
import Logging

struct RotatingFileLogHandler: LogHandler {
  var logLevel: Logger.Level = .info
  var metadata: Logger.Metadata = [:]

  subscript(metadataKey key: String) -> Logger.Metadata.Value? {
    get { metadata[key] }
    set { metadata[key] = newValue }
  }

  private let label: String
  private static let queue = DispatchQueue(label: "com.frame.log-writer")
  private static let maxFileSize: UInt64 = 5 * 1024 * 1024  // 5 MB
  private static let maxFiles = 3

  private static var logDirectory: URL {
    let home = FileManager.default.homeDirectoryForCurrentUser
    return home.appendingPathComponent("Library/Logs/Frame", isDirectory: true)
  }

  private static var logFile: URL {
    logDirectory.appendingPathComponent("frame.log")
  }

  init(label: String) {
    self.label = label
    Self.queue.sync {
      try? FileManager.default.createDirectory(at: Self.logDirectory, withIntermediateDirectories: true)
    }
  }

  func log(
    level: Logger.Level,
    message: Logger.Message,
    metadata: Logger.Metadata?,
    source: String,
    file: String,
    function: String,
    line: UInt
  ) {
    let merged = self.metadata.merging(metadata ?? [:]) { _, new in new }
    let metaString = merged.isEmpty ? "" : " \(merged)"
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let entry = "[\(timestamp)] [\(level)] [\(label)] \(message)\(metaString)\n"

    Self.queue.async {
      Self.rotateIfNeeded()
      if let data = entry.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: Self.logFile.path) {
          if let handle = try? FileHandle(forWritingTo: Self.logFile) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
          }
        } else {
          try? data.write(to: Self.logFile)
        }
      }
    }
  }

  private static func rotateIfNeeded() {
    guard let attrs = try? FileManager.default.attributesOfItem(atPath: logFile.path),
      let size = attrs[.size] as? UInt64,
      size >= maxFileSize
    else { return }

    let fm = FileManager.default
    for i in stride(from: maxFiles, through: 1, by: -1) {
      let older = logDirectory.appendingPathComponent("frame.\(i).log")
      if i == maxFiles {
        try? fm.removeItem(at: older)
      } else {
        let dest = logDirectory.appendingPathComponent("frame.\(i + 1).log")
        try? fm.moveItem(at: older, to: dest)
      }
    }
    let first = logDirectory.appendingPathComponent("frame.1.log")
    try? fm.moveItem(at: logFile, to: first)
  }
}
