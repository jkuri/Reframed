import Foundation

extension FileManager {
  func tempRecordingURL() -> URL {
    let tempDir = temporaryDirectory.appendingPathComponent("Frame", isDirectory: true)
    try? createDirectory(at: tempDir, withIntermediateDirectories: true)
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd-HHmmss"
    let filename = "frame-\(formatter.string(from: Date())).mp4"
    return tempDir.appendingPathComponent(filename)
  }

  func defaultSaveDirectory() -> URL {
    let homeDir = homeDirectoryForCurrentUser
    let frameDir = homeDir.appendingPathComponent("Frame", isDirectory: true)
    try? createDirectory(at: frameDir, withIntermediateDirectories: true)
    return frameDir
  }

  func defaultSaveURL(for tempURL: URL) -> URL {
    defaultSaveDirectory().appendingPathComponent(tempURL.lastPathComponent)
  }

  func moveToFinal(from source: URL, to destination: URL) throws {
    if fileExists(atPath: destination.path) {
      try removeItem(at: destination)
    }
    try moveItem(at: source, to: destination)
  }
}
