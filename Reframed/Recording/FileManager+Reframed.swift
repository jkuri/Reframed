import Foundation

extension FileManager {
  private func reframedTempDir() -> URL {
    let tempDir = URL(fileURLWithPath: "/tmp/Reframed", isDirectory: true)
    try? createDirectory(at: tempDir, withIntermediateDirectories: true)
    return tempDir
  }

  private func timestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd-HHmmss"
    return formatter.string(from: Date())
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

  func moveToFinal(from source: URL, to destination: URL) throws {
    if fileExists(atPath: destination.path) {
      try removeItem(at: destination)
    }
    try moveItem(at: source, to: destination)
  }

  func reframedBundleURL(in directory: URL) -> URL {
    directory.appendingPathComponent("recording-\(timestamp()).frm")
  }

  func cleanupTempDir() {
    let tempDir = URL(fileURLWithPath: "/tmp/Reframed", isDirectory: true)
    guard let contents = try? contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) else { return }
    for file in contents {
      try? removeItem(at: file)
    }
  }
}
