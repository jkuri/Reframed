import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import Logging
@preconcurrency import ScreenCaptureKit

extension RecordingCoordinator {
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
    retinaCapture: Bool = false,
    hdrCapture: Bool = false
  ) async throws -> Date {
    var verifiedCam: (capture: WebcamCapture, info: VerifiedCamera)?
    var verifiedMic: MicrophoneCapture?

    if let existing = existingWebcam {
      verifiedCam = (existing.0, existing.1)
      logger.info("Using pre-existing camera: \(existing.1.width)x\(existing.1.height)")
    } else if let camId = cameraDeviceId {
      let (maxW, maxH) = CaptureMode.cameraMaxDimensions(for: cameraResolution)
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
    }

    pixelW = Int(round(sourceRect.width * displayScale)) & ~1
    pixelH = Int(round(sourceRect.height * displayScale)) & ~1
    if retinaCapture {
      pixelW = (pixelW * 2) & ~1
      pixelH = (pixelH * 2) & ~1
    }
    recordingFPS = fps
    captureQualityUsed = captureQuality
    hdrCaptureUsed = hdrCapture

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
      captureQuality: captureQuality,
      isHDR: hdrCapture
    )
    self.videoWriter = vidWriter

    let captureOrigin: CGPoint
    switch target {
    case .region(let selection):
      captureOrigin = selection.screenCaptureKitRect.origin
    case .window(let window):
      captureOrigin = window.frame.origin
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

    let session = ScreenCaptureSession(videoWriter: vidWriter, captureQuality: captureQuality, hdrCapture: hdrCapture)
    session.onStreamError = { [weak self] error in
      guard let self else { return }
      Task { await self.handleStreamError(error) }
    }
    let selfApp = content.applications.first { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
    do {
      try await session.start(
        target: target,
        display: display,
        displayScale: displayScale,
        fps: fps,
        hideCursor: cursorMetadataRecorder != nil,
        retinaCapture: retinaCapture,
        excludedApps: [selfApp].compactMap { $0 }
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
        clock: clock,
        isWebcam: true
      )
      self.webcamWriter = camWriter
      cam.attachWriter(camWriter)
      cam.onDisconnected = { [weak self] in
        guard let self else { return }
        Task { await self.handleDeviceLost("camera") }
      }
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
      mic.onDisconnected = { [weak self] in
        guard let self else { return }
        Task { await self.handleDeviceLost("microphone") }
      }
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

    let videoRef = vidWriter
    systemAudioWriter?.setVideoPTSProvider { videoRef.lastWrittenPTS }
    micAudioWriter?.setVideoPTSProvider { videoRef.lastWrittenPTS }

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
}
