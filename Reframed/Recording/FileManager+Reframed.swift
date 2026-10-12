import Foundation

extension FileManager {
  private func reframedTempDir() -> URL {
    let tempDir = URL(fileURLWithPath: "/tmp/Reframed", isDirectory: true)
    try? createDirectory(at: tempDir, withIntermediateDirectories: true)
    return tempDir
  }

  private func timestamp() -> String {
    formatTimestamp()
  }

  func tempRecordingURL() -> URL {
    reframedTempDir().appendingPathComponent("reframed-\(timestamp()).mp4")
  }

  func tempVideoURL(captureQuality: CaptureQuality = .standard) -> URL {
    let ext = captureQuality.isProRes ? "mov" : "mp4"
    return reframedTempDir().appendingPathComponent("video-\(timestamp()).\(ext)")
  }

  func tempWebcamURL() -> URL {
    reframedTempDir().appendingPathComponent("webcam-\(timestamp()).mp4")
  }

  func tempAudioURL(label: String) -> URL {
    reframedTempDir().appendingPathComponent("\(label)-\(timestamp()).m4a")
  }

  func tempGIFURL() -> URL {
    reframedTempDir().appendingPathComponent("reframed-\(timestamp()).gif")
  }

  @MainActor
  func projectSaveDirectory() -> URL {
    let folderPath = ConfigService.shared.projectFolder
    let expanded = NSString(string: folderPath).expandingTildeInPath
    let url = URL(fileURLWithPath: expanded, isDirectory: true)
    try? createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @MainActor
  func defaultSaveDirectory() -> URL {
    let folderPath = ConfigService.shared.outputFolder
    let expanded = NSString(string: folderPath).expandingTildeInPath
    let url = URL(fileURLWithPath: expanded, isDirectory: true)
    try? createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @MainActor
  func defaultSaveURL(for tempURL: URL, extension ext: String? = nil) -> URL {
    if let ext {
      let baseName = tempURL.deletingPathExtension().lastPathComponent
      return defaultSaveDirectory().appendingPathComponent("\(baseName).\(ext)")
    }
    return defaultSaveDirectory().appendingPathComponent(tempURL.lastPathComponent)
  }

  @MainActor
  func defaultExportURL(for tempURL: URL, extension ext: String, projectName: String) -> URL {
    let baseName =
      sanitizedExportBaseName(projectName)
      ?? tempURL.deletingPathExtension().lastPathComponent
    return uniqueExportURL(in: defaultSaveDirectory(), baseName: baseName, extension: ext)
  }

  private func sanitizedExportBaseName(_ name: String) -> String? {
    let disallowed = CharacterSet(charactersIn: "/:").union(.controlCharacters)
    let cleaned = name.components(separatedBy: disallowed).joined()
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned.isEmpty ? nil : cleaned
  }

  private func uniqueExportURL(in directory: URL, baseName: String, extension ext: String) -> URL {
    var candidate = directory.appendingPathComponent("\(baseName).\(ext)")
    var suffix = 2
    while fileExists(atPath: candidate.path) {
      candidate = directory.appendingPathComponent("\(baseName)-\(suffix).\(ext)")
      suffix += 1
    }
    return candidate
  }

  func moveToFinal(from source: URL, to destination: URL) throws {
    if fileExists(atPath: destination.path) {
      try removeItem(at: destination)
    }
    try moveItem(at: source, to: destination)
  }

  func cleanupTempDir() {
    let tempDir = URL(fileURLWithPath: "/tmp/Reframed", isDirectory: true)
    guard let contents = try? contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) else { return }
    for file in contents {
      try? removeItem(at: file)
    }
  }
}
