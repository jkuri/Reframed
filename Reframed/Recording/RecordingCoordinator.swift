import AVFoundation
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
  private var deviceCapture: DeviceCapture?
  private var deviceAudioWriter: AudioTrackWriter?
  private var videoWriter: VideoTrackWriter?
  private var webcamWriter: VideoTrackWriter?
  private var systemAudioWriter: AudioTrackWriter?
  private var micAudioWriter: AudioTrackWriter?
  private var recordingClock: SharedRecordingClock?
  private var cursorMetadataRecorder: CursorMetadataRecorder?
  private let logger = Logger(label: "eu.jankuri.reframed.recording-coordinator")
  private var pauseStartTime: CMTime = .invalid
  private var totalPauseOffset: CMTime = .zero
  private var pixelW: Int = 0
  private var pixelH: Int = 0
  private var webcamPixelW: Int = 0
  private var webcamPixelH: Int = 0
  private var recordingFPS: Int = 60
  private var captureQualityUsed: CaptureQuality = .standard

  func startRecording(
    target: CaptureTarget,
    fps: Int = 60,
    captureSystemAudio: Bool = false,
    microphoneDeviceId: String? = nil,
    cameraDeviceId: String? = nil,
    cameraResolution: String = "1080p",
    existingWebcam: (WebcamCapture, VerifiedCamera)? = nil,
    cursorMetadataRecorder: CursorMetadataRecorder? = nil,
    captureQuality: CaptureQuality = .standard,
    retinaCapture: Bool = false
  ) async throws -> Date {
    var verifiedCam: (capture: WebcamCapture, info: VerifiedCamera)?
    var verifiedMic: MicrophoneCapture?

    if let existing = existingWebcam {
      verifiedCam = (existing.0, existing.1)
      logger.info("Using pre-existing camera: \(existing.1.width)x\(existing.1.height)")
    } else if let camId = cameraDeviceId {
      let (maxW, maxH) = cameraMaxDimensions(for: cameraResolution)
      let cam = WebcamCapture()
      let info = try await cam.startAndVerify(deviceId: camId, fps: fps, maxWidth: maxW, maxHeight: maxH)
      verifiedCam = (cam, info)
      logger.info("Camera ready: \(info.width)x\(info.height)")
    }

    if let micId = microphoneDeviceId {
      let mic = MicrophoneCapture()
      do {
        try await mic.startAndVerify(deviceId: micId)
      } catch {
        verifiedCam?.capture.stop()
        throw error
      }
      verifiedMic = mic
      logger.info("Microphone ready")
    }

    let content: SCShareableContent
    do {
      content = try await Permissions.fetchShareableContent()
    } catch {
      verifiedCam?.capture.stop()
      verifiedMic?.stop()
      throw error
    }

    guard let display = content.displays.first(where: { $0.displayID == target.displayID }) else {
      verifiedCam?.capture.stop()
      verifiedMic?.stop()
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
    if retinaCapture {
      pixelW = (pixelW * 2) & ~1
      pixelH = (pixelH * 2) & ~1
    }
    recordingFPS = fps
    captureQualityUsed = captureQuality

    var streamCount = 1
    if verifiedMic != nil { streamCount += 1 }
    if captureSystemAudio { streamCount += 1 }
    if verifiedCam != nil { streamCount += 1 }

    let clock = SharedRecordingClock(streamCount: streamCount)
    self.recordingClock = clock

    let vidWriter = try VideoTrackWriter(
      outputURL: FileManager.default.tempVideoURL(captureQuality: captureQuality),
      width: pixelW,
      height: pixelH,
      fps: fps,
      clock: clock,
      captureQuality: captureQuality
    )
    self.videoWriter = vidWriter

    let captureOrigin: CGPoint
    switch target {
    case .region(let selection):
      captureOrigin = selection.screenCaptureKitRect.origin
    case .window(let window):
      captureOrigin = window.frame.origin
    case .screen:
      captureOrigin = display.frame.origin
    }

    if let cursorMetadataRecorder {
      cursorMetadataRecorder.configure(
        captureOrigin: captureOrigin,
        captureSize: sourceRect.size,
        displayScale: displayScale,
        displayHeight: CGFloat(CGDisplayPixelsHigh(display.displayID))
      )
      self.cursorMetadataRecorder = cursorMetadataRecorder
    }

    let session = ScreenCaptureSession(videoWriter: vidWriter, captureQuality: captureQuality)
    do {
      try await session.start(
        target: target,
        display: display,
        displayScale: displayScale,
        fps: fps,
        hideCursor: cursorMetadataRecorder != nil,
        retinaCapture: retinaCapture
      )
    } catch {
      verifiedCam?.capture.stop()
      verifiedMic?.stop()
      throw error
    }
    self.captureSession = session

    if let (cam, info) = verifiedCam {
      let camW = info.width & ~1
      let camH = info.height & ~1
      webcamPixelW = camW
      webcamPixelH = camH

      let camWriter = try VideoTrackWriter(
        outputURL: FileManager.default.tempWebcamURL(),
        width: camW,
        height: camH,
        fps: fps,
        clock: clock
      )
      self.webcamWriter = camWriter
      cam.attachWriter(camWriter)
      self.webcamCapture = cam
    }

    if let mic = verifiedMic, let micId = microphoneDeviceId {
      let micFmt = MicrophoneCapture.targetFormat(deviceId: micId)
      let micWriter = try AudioTrackWriter(
        outputURL: FileManager.default.tempAudioURL(label: "mic"),
        label: "mic",
        sampleRate: micFmt?.sampleRate ?? 48000,
        channelCount: micFmt?.channelCount ?? 1,
        clock: clock
      )
      self.micAudioWriter = micWriter
      mic.attachWriter(micWriter)
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

  func startDeviceRecording(
    deviceCapture: DeviceCapture,
    fps: Int = 60,
    microphoneDeviceId: String? = nil,
    cameraDeviceId: String? = nil,
    cameraResolution: String = "1080p",
    existingWebcam: (WebcamCapture, VerifiedCamera)? = nil,
    captureQuality: CaptureQuality = .standard,
    retinaCapture: Bool = false
  ) async throws -> Date {
    var verifiedCam: (capture: WebcamCapture, info: VerifiedCamera)?
    var verifiedMic: MicrophoneCapture?

    if let existing = existingWebcam {
      verifiedCam = (existing.0, existing.1)
      logger.info("Using pre-existing camera for device recording: \(existing.1.width)x\(existing.1.height)")
    } else if let camId = cameraDeviceId {
      let (maxW, maxH) = cameraMaxDimensions(for: cameraResolution)
      let cam = WebcamCapture()
      let info = try await cam.startAndVerify(deviceId: camId, fps: fps, maxWidth: maxW, maxHeight: maxH)
      verifiedCam = (cam, info)
      logger.info("Camera ready for device recording: \(info.width)x\(info.height)")
    }

    if let micId = microphoneDeviceId {
      let mic = MicrophoneCapture()
      do {
        try await mic.startAndVerify(deviceId: micId)
      } catch {
        if existingWebcam == nil { verifiedCam?.capture.stop() }
        throw error
      }
      verifiedMic = mic
      logger.info("Microphone ready for device recording")
    }

    guard let session = deviceCapture.captureSession,
      let videoOutput = session.outputs.first(where: { $0 is AVCaptureVideoDataOutput }),
      let connection = videoOutput.connection(with: .video)
    else {
      verifiedMic?.stop()
      if existingWebcam == nil { verifiedCam?.capture.stop() }
      throw CaptureError.deviceStreamFailed
    }

    var rawW = 0
    var rawH = 0
    if let port = connection.inputPorts.first(where: { $0.mediaType == .video }),
      let desc = port.formatDescription
    {
      let d = CMVideoFormatDescriptionGetDimensions(desc)
      rawW = Int(d.width)
      rawH = Int(d.height)
    }
    let angle = connection.videoRotationAngle
    let isRotated = angle == 90 || angle == 270
    var pW = (isRotated ? rawH : rawW) & ~1
    var pH = (isRotated ? rawW : rawH) & ~1
    if pW == 0 || pH == 0 {
      pW = 1920
      pH = 1080
    }
    if retinaCapture {
      pW = (pW * 2) & ~1
      pH = (pH * 2) & ~1
    }

    pixelW = pW
    pixelH = pH
    recordingFPS = fps
    captureQualityUsed = captureQuality

    var streamCount = 1
    if verifiedMic != nil { streamCount += 1 }
    if verifiedCam != nil { streamCount += 1 }
    let hasDeviceAudio = session.outputs.contains(where: { $0 is AVCaptureAudioDataOutput })
    if hasDeviceAudio { streamCount += 1 }

    let clock = SharedRecordingClock(streamCount: streamCount)
    self.recordingClock = clock

    let vidWriter = try VideoTrackWriter(
      outputURL: FileManager.default.tempVideoURL(captureQuality: captureQuality),
      width: pW,
      height: pH,
      fps: fps,
      clock: clock,
      captureQuality: captureQuality
    )
    self.videoWriter = vidWriter
    deviceCapture.attachVideoWriter(vidWriter)

    if hasDeviceAudio {
      let devAudioWriter = try AudioTrackWriter(
        outputURL: FileManager.default.tempAudioURL(label: "device-audio"),
        label: "device-audio",
        sampleRate: 48000,
        channelCount: 2,
        clock: clock
      )
      self.deviceAudioWriter = devAudioWriter
      deviceCapture.attachAudioWriter(devAudioWriter)
    }

    self.deviceCapture = deviceCapture

    if let (cam, info) = verifiedCam {
      let camW = info.width & ~1
      let camH = info.height & ~1
      webcamPixelW = camW
      webcamPixelH = camH

      let camWriter = try VideoTrackWriter(
        outputURL: FileManager.default.tempWebcamURL(),
        width: camW,
        height: camH,
        fps: fps,
        clock: clock
      )
      self.webcamWriter = camWriter
      cam.attachWriter(camWriter)
      self.webcamCapture = cam
    }

    if let mic = verifiedMic, let micId = microphoneDeviceId {
      let micFmt = MicrophoneCapture.targetFormat(deviceId: micId)
      let micWriter = try AudioTrackWriter(
        outputURL: FileManager.default.tempAudioURL(label: "mic"),
        label: "mic",
        sampleRate: micFmt?.sampleRate ?? 48000,
        channelCount: micFmt?.channelCount ?? 1,
        clock: clock
      )
      self.micAudioWriter = micWriter
      mic.attachWriter(micWriter)
      self.microphoneCapture = mic
    }

    let startedAt = Date()
    logger.info(
      "Device recording started",
      metadata: [
        "width": "\(pW)",
        "height": "\(pH)",
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
    deviceCapture?.pause()
    videoWriter?.pause()
    webcamWriter?.pause()
    systemAudioWriter?.pause()
    micAudioWriter?.pause()
    deviceAudioWriter?.pause()
    cursorMetadataRecorder?.pause()
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
    deviceAudioWriter?.resume(withOffset: totalPauseOffset)
    captureSession?.resume()
    systemAudioCapture?.resume()
    microphoneCapture?.resume()
    webcamCapture?.resume()
    deviceCapture?.resume()
    cursorMetadataRecorder?.resume()
    logger.info("Recording resumed, total offset: \(CMTimeGetSeconds(totalPauseOffset))s")
  }

  func stopRecordingRaw(keepWebcamAlive: Bool = false) async throws -> RecordingResult? {
    cursorMetadataRecorder?.stop()

    microphoneCapture?.stop()
    microphoneCapture = nil

    if keepWebcamAlive {
      webcamCapture?.detachWriter()
    } else {
      webcamCapture?.stop()
      webcamCapture = nil
    }

    deviceCapture?.stop()
    deviceCapture = nil

    try await systemAudioCapture?.stop()
    systemAudioCapture = nil

    try await captureSession?.stop()
    captureSession = nil

    async let videoResult = videoWriter?.finish()
    async let webcamResult = webcamWriter?.finish()
    async let sysAudioResult = systemAudioWriter?.finish()
    async let micResult = micAudioWriter?.finish()
    async let deviceAudioResult = deviceAudioWriter?.finish()

    let videoURL = await videoResult
    let webcamURL = await webcamResult
    let sysAudioURL = await sysAudioResult
    let micURL = await micResult
    let deviceAudioURL = await deviceAudioResult

    var cursorMetadataURL: URL?
    if let recorder = cursorMetadataRecorder {
      if let refTime = recordingClock?.referenceTimeSeconds {
        let cursorStart = recorder.startHostTimeSeconds
        let offset = cursorStart - refTime
        if abs(offset) > 0.001 {
          recorder.adjustTimestamps(by: offset)
          logger.info("Cursor metadata adjusted by \(String(format: "%.3f", offset))s to sync with video clock")
        }
      }

      let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("cursor-metadata-\(UUID().uuidString).json")
      do {
        try recorder.writeToFile(at: tempURL)
        cursorMetadataURL = tempURL
      } catch {
        logger.error("Failed to write cursor metadata: \(error)")
      }
    }
    cursorMetadataRecorder = nil

    let screenW = pixelW
    let screenH = pixelH
    let camW = webcamPixelW
    let camH = webcamPixelH
    let fps = recordingFPS

    videoWriter = nil
    webcamWriter = nil
    systemAudioWriter = nil
    micAudioWriter = nil
    deviceAudioWriter = nil
    recordingClock = nil

    guard let videoFile = videoURL else {
      logger.error("Video writer produced no output")
      return nil
    }

    return RecordingResult(
      screenVideoURL: videoFile,
      webcamVideoURL: webcamURL,
      systemAudioURL: sysAudioURL ?? deviceAudioURL,
      microphoneAudioURL: micURL,
      cursorMetadataURL: cursorMetadataURL,
      screenSize: CGSize(width: screenW, height: screenH),
      webcamSize: webcamURL != nil ? CGSize(width: camW, height: camH) : nil,
      fps: fps,
      captureQuality: captureQualityUsed
    )
  }

  func stopRecording(keepWebcamAlive: Bool = false) async throws -> URL? {
    microphoneCapture?.stop()
    microphoneCapture = nil

    if keepWebcamAlive {
      webcamCapture?.detachWriter()
    } else {
      webcamCapture?.stop()
      webcamCapture = nil
    }

    deviceCapture?.stop()
    deviceCapture = nil

    try await systemAudioCapture?.stop()
    systemAudioCapture = nil

    try await captureSession?.stop()
    captureSession = nil

    async let videoResult = videoWriter?.finish()
    async let webcamResult = webcamWriter?.finish()
    async let sysAudioResult = systemAudioWriter?.finish()
    async let micResult = micAudioWriter?.finish()
    async let deviceAudioResult = deviceAudioWriter?.finish()

    let videoURL = await videoResult
    _ = await webcamResult
    let sysAudioURL = await sysAudioResult
    let micURL = await micResult
    let deviceAudioURL = await deviceAudioResult

    videoWriter = nil
    webcamWriter = nil
    systemAudioWriter = nil
    micAudioWriter = nil
    deviceAudioWriter = nil
    recordingClock = nil

    guard let videoFile = videoURL else {
      logger.error("Video writer produced no output")
      return nil
    }

    var audioFiles: [URL] = []
    if let sysURL = sysAudioURL { audioFiles.append(sysURL) }
    if let devURL = deviceAudioURL { audioFiles.append(devURL) }
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

  func getAudioLevels() -> (mic: Float, system: Float) {
    let mic = micAudioWriter?.currentPeakLevel ?? 0
    let sys = systemAudioWriter?.currentPeakLevel ?? 0
    return (mic, sys)
  }

  func getWebcamCaptureSessionBox() -> SendableBox<AVCaptureSession>? {
    guard let session = webcamCapture?.captureSession else { return nil }
    return SendableBox(session)
  }

  func getWebcamCapture() -> WebcamCapture? {
    webcamCapture
  }

  private func cameraMaxDimensions(for resolution: String) -> (Int, Int) {
    switch resolution {
    case "720p":
      return (1280, 720)
    case "4K":
      return (3840, 2160)
    default:
      return (1920, 1080)
    }
  }
}
