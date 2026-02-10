import CoreGraphics
import Foundation
import Logging
@preconcurrency import ScreenCaptureKit

actor RecordingCoordinator {
  private var captureSession: ScreenCaptureSession?
  private var systemAudioCapture: SystemAudioCapture?
  private var microphoneCapture: MicrophoneCapture?
  private var videoWriter: VideoTrackWriter?
  private var systemAudioWriter: AudioTrackWriter?
  private var micAudioWriter: AudioTrackWriter?
  private let logger = Logger(label: "eu.jankuri.frame.recording-coordinator")

  func startRecording(
    target: CaptureTarget,
    fps: Int = 60,
    captureSystemAudio: Bool = false,
    microphoneDeviceId: String? = nil
  ) async throws -> Date {
    let content = try await Permissions.fetchShareableContent()
    guard let display = content.displays.first(where: { $0.displayID == target.displayID }) else {
      throw CaptureError.displayNotFound
    }

    let displayScale: CGFloat = {
      guard let mode = CGDisplayCopyDisplayMode(target.displayID) else { return 2.0 }
      let px = CGFloat(mode.pixelWidth)
      let pt = CGFloat(mode.width)
      return pt > 0 ? px / pt : 2.0
    }()

    let sourceRect: CGRect
    switch target {
    case .region(let selection):
      sourceRect = selection.screenCaptureKitRect
    case .window(let window):
      sourceRect = CGRect(origin: .zero, size: CGSize(width: CGFloat(window.frame.width), height: CGFloat(window.frame.height)))
    case .screen(let screen):
      sourceRect = screen.frame
    }

    let pixelW = Int(round(sourceRect.width * displayScale)) & ~1
    let pixelH = Int(round(sourceRect.height * displayScale)) & ~1

    let vidWriter = try VideoTrackWriter(
      outputURL: FileManager.default.tempVideoURL(),
      width: pixelW,
      height: pixelH
    )
    self.videoWriter = vidWriter

    let session = ScreenCaptureSession(videoWriter: vidWriter)
    try await session.start(target: target, display: display, displayScale: displayScale, fps: fps)
    self.captureSession = session

    if let micId = microphoneDeviceId {
      let micFmt = MicrophoneCapture.targetFormat(deviceId: micId)
      let micWriter = try AudioTrackWriter(
        outputURL: FileManager.default.tempAudioURL(label: "mic"),
        label: "mic",
        sampleRate: micFmt?.sampleRate ?? 48000,
        channelCount: micFmt?.channelCount ?? 1
      )
      self.micAudioWriter = micWriter

      let mic = MicrophoneCapture(audioWriter: micWriter)
      try await mic.start(deviceId: micId)
      self.microphoneCapture = mic
    }

    if captureSystemAudio {
      let sysWriter = try AudioTrackWriter(
        outputURL: FileManager.default.tempAudioURL(label: "sysaudio"),
        label: "sysaudio",
        sampleRate: 48000,
        channelCount: 2
      )
      self.systemAudioWriter = sysWriter

      let sysCapture = SystemAudioCapture(audioWriter: sysWriter)
      try await sysCapture.start(display: display)
      self.systemAudioCapture = sysCapture
    }

    let startedAt = Date()
    logger.info(
      "Recording started",
      metadata: [
        "systemAudio": "\(captureSystemAudio)",
        "microphone": "\(microphoneDeviceId ?? "none")",
      ]
    )
    return startedAt
  }

  func stopRecording() async throws -> URL? {
    microphoneCapture?.stop()
    microphoneCapture = nil

    try await systemAudioCapture?.stop()
    systemAudioCapture = nil

    try await captureSession?.stop()
    captureSession = nil

    async let videoResult = videoWriter?.finish()
    async let sysAudioResult = systemAudioWriter?.finish()
    async let micResult = micAudioWriter?.finish()

    let videoURL = await videoResult
    let sysAudioURL = await sysAudioResult
    let micURL = await micResult

    videoWriter = nil
    systemAudioWriter = nil
    micAudioWriter = nil

    guard let videoFile = videoURL else {
      logger.error("Video writer produced no output")
      return nil
    }

    var audioFiles: [URL] = []
    if let sysURL = sysAudioURL { audioFiles.append(sysURL) }
    if let micFile = micURL { audioFiles.append(micFile) }

    let outputURL: URL
    if audioFiles.isEmpty {
      outputURL = videoFile
    } else {
      let mergedURL = FileManager.default.tempRecordingURL()
      outputURL = try await VideoTranscoder.merge(videoFile: videoFile, audioFiles: audioFiles, to: mergedURL)
    }

    let destination = await MainActor.run { FileManager.default.defaultSaveURL(for: outputURL) }
    try FileManager.default.moveToFinal(from: outputURL, to: destination)

    logger.info("Recording saved", metadata: ["path": "\(destination.path)"])
    return destination
  }
}
