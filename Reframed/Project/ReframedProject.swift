import CoreGraphics
import Foundation

struct ReframedProject: Sendable {
  var bundleURL: URL
  var metadata: ProjectMetadata

  var name: String {
    metadata.name ?? bundleURL.deletingPathExtension().lastPathComponent
  }

  var screenVideoURL: URL {
    let movURL = bundleURL.appendingPathComponent("screen.mov")
    if FileManager.default.fileExists(atPath: movURL.path) {
      return movURL
    }
    return bundleURL.appendingPathComponent("screen.mp4")
  }

  var webcamVideoURL: URL? {
    let url = bundleURL.appendingPathComponent("webcam.mp4")
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }

  var systemAudioURL: URL? {
    let url = bundleURL.appendingPathComponent("system-audio.m4a")
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }

  var microphoneAudioURL: URL? {
    let url = bundleURL.appendingPathComponent("mic-audio.m4a")
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }

  var denoisedMicAudioURL: URL? {
    let url = bundleURL.appendingPathComponent("denoised-mic.m4a")
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }

  var denoisedMicAudioDestinationURL: URL {
    bundleURL.appendingPathComponent("denoised-mic.m4a")
  }

  var cursorMetadataURL: URL? {
    let url = bundleURL.appendingPathComponent("cursor-metadata.json")
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }

  var recordingResult: RecordingResult {
    RecordingResult(
      screenVideoURL: screenVideoURL,
      webcamVideoURL: webcamVideoURL,
      systemAudioURL: systemAudioURL,
      microphoneAudioURL: microphoneAudioURL,
      cursorMetadataURL: cursorMetadataURL,
      screenSize: metadata.screenSize.cgSize,
      webcamSize: metadata.webcamSize?.cgSize,
      fps: metadata.fps,
      captureQuality: CaptureQuality(rawValue: metadata.captureQuality ?? "standard") ?? .standard
    )
  }

  static func create(
    from result: RecordingResult,
    fps: Int,
    captureMode: CaptureMode,
    in directory: URL
  ) throws
    -> ReframedProject
  {
    let fm = FileManager.default
    let bundleName = "recording-\(timestamp()).frm"
    let bundleURL = directory.appendingPathComponent(bundleName)
    try fm.createDirectory(at: bundleURL, withIntermediateDirectories: true)

    let screenExt = result.screenVideoURL.pathExtension
    try fm.moveItem(at: result.screenVideoURL, to: bundleURL.appendingPathComponent("screen.\(screenExt)"))

    if let webcamURL = result.webcamVideoURL {
      try fm.moveItem(at: webcamURL, to: bundleURL.appendingPathComponent("webcam.mp4"))
    }

    if let sysURL = result.systemAudioURL {
      try fm.moveItem(at: sysURL, to: bundleURL.appendingPathComponent("system-audio.m4a"))
    }

    if let micURL = result.microphoneAudioURL {
      try fm.moveItem(at: micURL, to: bundleURL.appendingPathComponent("mic-audio.m4a"))
    }

    if let cursorURL = result.cursorMetadataURL {
      try fm.moveItem(at: cursorURL, to: bundleURL.appendingPathComponent("cursor-metadata.json"))
    }

    fm.cleanupTempDir()

    let metadata = ProjectMetadata(
      createdAt: Date(),
      fps: fps,
      screenSize: CodableSize(result.screenSize),
      webcamSize: result.webcamSize.map { CodableSize($0) },
      hasSystemAudio: result.systemAudioURL != nil,
      hasMicrophoneAudio: result.microphoneAudioURL != nil,
      hasCursorMetadata: result.cursorMetadataURL != nil,
      hasWebcam: result.webcamVideoURL != nil,
      captureMode: captureMode,
      captureQuality: result.captureQuality.rawValue
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(metadata)
    try data.write(to: bundleURL.appendingPathComponent("project.json"))

    return ReframedProject(bundleURL: bundleURL, metadata: metadata)
  }

  static func open(at url: URL) throws -> ReframedProject {
    let jsonURL = url.appendingPathComponent("project.json")
    let data = try Data(contentsOf: jsonURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let metadata = try decoder.decode(ProjectMetadata.self, from: data)

    let project = ReframedProject(bundleURL: url, metadata: metadata)

    guard FileManager.default.fileExists(atPath: project.screenVideoURL.path) else {
      throw CaptureError.recordingFailed("Screen recording file missing from project bundle")
    }

    return project
  }

  func saveEditorState(_ state: EditorStateData) throws {
    var updated = metadata
    updated.editorState = state
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(updated)
    try data.write(to: bundleURL.appendingPathComponent("project.json"))
  }

  mutating func rename(to newName: String) throws {
    metadata.name = newName

    let sanitized =
      newName
      .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_")).inverted)
      .joined()
    let dirName = sanitized.isEmpty ? newName : sanitized
    let newBundleURL = bundleURL.deletingLastPathComponent().appendingPathComponent("\(dirName).frm")

    if newBundleURL != bundleURL && !FileManager.default.fileExists(atPath: newBundleURL.path) {
      try FileManager.default.moveItem(at: bundleURL, to: newBundleURL)
      bundleURL = newBundleURL
    }

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(metadata)
    try data.write(to: bundleURL.appendingPathComponent("project.json"))
  }

  func saveHistory(_ data: HistoryData) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let jsonData = try encoder.encode(data)
    try jsonData.write(to: bundleURL.appendingPathComponent("history.json"))
  }

  func loadHistory() -> HistoryData? {
    let url = bundleURL.appendingPathComponent("history.json")
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(HistoryData.self, from: data)
  }

  func delete() throws {
    try FileManager.default.removeItem(at: bundleURL)
  }

  private static func timestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd-HHmmss"
    return formatter.string(from: Date())
  }
}
