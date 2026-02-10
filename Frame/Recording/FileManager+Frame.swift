import Foundation

extension FileManager {
  private func frameTempDir() -> URL {
    let tempDir = URL(fileURLWithPath: "/tmp/Frame", isDirectory: true)
    try? createDirectory(at: tempDir, withIntermediateDirectories: true)
    return tempDir
  }

  private func timestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd-HHmmss"
    return formatter.string(from: Date())
  }

  func tempRecordingURL() -> URL {
    frameTempDir().appendingPathComponent("frame-\(timestamp()).mp4")
  }

  func tempVideoURL() -> URL {
    frameTempDir().appendingPathComponent("video-\(timestamp()).mp4")
  }

  func tempAudioURL(label: String) -> URL {
    frameTempDir().appendingPathComponent("\(label)-\(timestamp()).m4a")
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
  func defaultSaveURL(for tempURL: URL) -> URL {
    defaultSaveDirectory().appendingPathComponent(tempURL.lastPathComponent)
  }

  func moveToFinal(from source: URL, to destination: URL) throws {
    if fileExists(atPath: destination.path) {
      try removeItem(at: destination)
    }
    try moveItem(at: source, to: destination)
  }

  func cleanupTempDir() {
    let tempDir = URL(fileURLWithPath: "/tmp/Frame", isDirectory: true)
    guard let contents = try? contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) else { return }
    for file in contents {
      try? removeItem(at: file)
    }
  }
}
