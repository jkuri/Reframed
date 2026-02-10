import CoreGraphics
import CoreMedia
import Foundation
import Logging
@preconcurrency import ScreenCaptureKit

actor RecordingCoordinator {
  private var captureSession: ScreenCaptureSession?
  private var systemAudioCapture: SystemAudioCapture?
  private var microphoneCapture: MicrophoneCapture?
  private var webcamCapture: WebcamCapture?
  private var videoWriter: VideoTrackWriter?
  private var webcamWriter: VideoTrackWriter?
  private var systemAudioWriter: AudioTrackWriter?
  private var micAudioWriter: AudioTrackWriter?
  private var recordingClock: SharedRecordingClock?
  private let logger = Logger(label: "eu.jankuri.frame.recording-coordinator")
  private var pauseStartTime: CMTime = .invalid
  private var totalPauseOffset: CMTime = .zero
  private var pixelW: Int = 0
  private var pixelH: Int = 0
  private var webcamPixelW: Int = 0
  private var webcamPixelH: Int = 0
  private var recordingFPS: Int = 60

  func startRecording(
    target: CaptureTarget,
    fps: Int = 60,
    captureSystemAudio: Bool = false,
    microphoneDeviceId: String? = nil,
    cameraDeviceId: String? = nil
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

    pixelW = Int(round(sourceRect.width * displayScale)) & ~1
    pixelH = Int(round(sourceRect.height * displayScale)) & ~1
    recordingFPS = fps

    var streamCount = 1
    if microphoneDeviceId != nil { streamCount += 1 }
    if captureSystemAudio { streamCount += 1 }
    if cameraDeviceId != nil { streamCount += 1 }

    let clock = SharedRecordingClock(streamCount: streamCount)
    self.recordingClock = clock

    let vidWriter = try VideoTrackWriter(
      outputURL: FileManager.default.tempVideoURL(),
      width: pixelW,
      height: pixelH,
      clock: clock
    )
    self.videoWriter = vidWriter

    let session = ScreenCaptureSession(videoWriter: vidWriter)
    try await session.start(target: target, display: display, displayScale: displayScale, fps: fps)
    self.captureSession = session

    if let camId = cameraDeviceId {
      let camWriter = try VideoTrackWriter(
        outputURL: FileManager.default.tempWebcamURL(),
        width: 1280,
        height: 720,
        clock: clock
      )
      self.webcamWriter = camWriter

      let cam = WebcamCapture(videoWriter: camWriter)
      try await cam.start(deviceId: camId, fps: fps)
      self.webcamCapture = cam

      if let camSession = cam.captureSession,
        let input = camSession.inputs.first as? AVCaptureDeviceInput
      {
        let dims = CMVideoFormatDescriptionGetDimensions(input.device.activeFormat.formatDescription)
        webcamPixelW = Int(dims.width)
        webcamPixelH = Int(dims.height)
      } else {
        webcamPixelW = 1280
        webcamPixelH = 720
      }
    }

    if let micId = microphoneDeviceId {
      let micFmt = MicrophoneCapture.targetFormat(deviceId: micId)
      let micWriter = try AudioTrackWriter(
        outputURL: FileManager.default.tempAudioURL(label: "mic"),
        label: "mic",
        sampleRate: micFmt?.sampleRate ?? 48000,
        channelCount: micFmt?.channelCount ?? 1,
        clock: clock
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
        channelCount: 2,
        clock: clock
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
        "camera": "\(cameraDeviceId ?? "none")",
      ]
    )
    return startedAt
  }

  func pause() {
    pauseStartTime = CMClockGetTime(CMClockGetHostTimeClock())
    captureSession?.pause()
    systemAudioCapture?.pause()
    microphoneCapture?.pause()
    webcamCapture?.pause()
    videoWriter?.pause()
    webcamWriter?.pause()
    systemAudioWriter?.pause()
    micAudioWriter?.pause()
    logger.info("Recording paused")
  }

  func resume() {
    if pauseStartTime.isValid {
      let now = CMClockGetTime(CMClockGetHostTimeClock())
      let pauseDuration = CMTimeSubtract(now, pauseStartTime)
      totalPauseOffset = CMTimeAdd(totalPauseOffset, pauseDuration)
      pauseStartTime = .invalid
    }
    videoWriter?.resume(withOffset: totalPauseOffset)
    webcamWriter?.resume(withOffset: totalPauseOffset)
    systemAudioWriter?.resume(withOffset: totalPauseOffset)
    micAudioWriter?.resume(withOffset: totalPauseOffset)
    captureSession?.resume()
    systemAudioCapture?.resume()
    microphoneCapture?.resume()
    webcamCapture?.resume()
    logger.info("Recording resumed, total offset: \(CMTimeGetSeconds(totalPauseOffset))s")
  }

  func stopRecordingRaw() async throws -> RecordingResult? {
    microphoneCapture?.stop()
    microphoneCapture = nil

    webcamCapture?.stop()
    webcamCapture = nil

    try await systemAudioCapture?.stop()
    systemAudioCapture = nil

    try await captureSession?.stop()
    captureSession = nil

    async let videoResult = videoWriter?.finish()
    async let webcamResult = webcamWriter?.finish()
    async let sysAudioResult = systemAudioWriter?.finish()
    async let micResult = micAudioWriter?.finish()

    let videoURL = await videoResult
    let webcamURL = await webcamResult
    let sysAudioURL = await sysAudioResult
    let micURL = await micResult

    let screenW = pixelW
    let screenH = pixelH
    let camW = webcamPixelW
    let camH = webcamPixelH
    let fps = recordingFPS

    videoWriter = nil
    webcamWriter = nil
    systemAudioWriter = nil
    micAudioWriter = nil
    recordingClock = nil

    guard let videoFile = videoURL else {
      logger.error("Video writer produced no output")
      return nil
    }

    return RecordingResult(
      screenVideoURL: videoFile,
      webcamVideoURL: webcamURL,
      systemAudioURL: sysAudioURL,
      microphoneAudioURL: micURL,
      screenSize: CGSize(width: screenW, height: screenH),
      webcamSize: webcamURL != nil ? CGSize(width: camW, height: camH) : nil,
      fps: fps
    )
  }

  func stopRecording() async throws -> URL? {
    microphoneCapture?.stop()
    microphoneCapture = nil

    webcamCapture?.stop()
    webcamCapture = nil

    try await systemAudioCapture?.stop()
    systemAudioCapture = nil

    try await captureSession?.stop()
    captureSession = nil

    async let videoResult = videoWriter?.finish()
    async let webcamResult = webcamWriter?.finish()
    async let sysAudioResult = systemAudioWriter?.finish()
    async let micResult = micAudioWriter?.finish()

    let videoURL = await videoResult
    _ = await webcamResult
    let sysAudioURL = await sysAudioResult
    let micURL = await micResult

    videoWriter = nil
    webcamWriter = nil
    systemAudioWriter = nil
    micAudioWriter = nil
    recordingClock = nil

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
      outputURL = try await VideoTranscoder.merge(
        videoFile: videoFile,
        audioFiles: audioFiles,
        to: mergedURL
      )
    }

    let destination = await MainActor.run { FileManager.default.defaultSaveURL(for: outputURL) }
    try FileManager.default.moveToFinal(from: outputURL, to: destination)
    FileManager.default.cleanupTempDir()

    logger.info("Recording saved", metadata: ["path": "\(destination.path)"])
    return destination
  }

  func getWebcamCaptureSessionBox() -> SendableBox<AVCaptureSession>? {
    guard let session = webcamCapture?.captureSession else { return nil }
    return SendableBox(session)
  }
}
