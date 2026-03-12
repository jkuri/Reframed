import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation

extension RecordingCoordinator {
  func startDeviceRecording(
    deviceCapture: DeviceCapture,
    fps: Int = 60,
    microphoneDeviceId: String? = nil,
    cameraDeviceId: String? = nil,
    cameraResolution: String = "1080p",
    existingWebcam: (WebcamCapture, VerifiedCamera)? = nil,
    captureQuality: CaptureQuality = .standard,
    retinaCapture: Bool = false,
    hdrCapture: Bool = false
  ) async throws -> Date {
    var verifiedCam: (capture: WebcamCapture, info: VerifiedCamera)?
    var verifiedMic: MicrophoneCapture?

    if let existing = existingWebcam {
      verifiedCam = (existing.0, existing.1)
      logger.info("Using pre-existing camera for device recording: \(existing.1.width)x\(existing.1.height)")
    } else if let camId = cameraDeviceId {
      let (maxW, maxH) = CaptureMode.cameraMaxDimensions(for: cameraResolution)
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
    hdrCaptureUsed = hdrCapture

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
      captureQuality: captureQuality,
      isHDR: hdrCapture
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

    let videoRef = vidWriter
    deviceAudioWriter?.setVideoPTSProvider { videoRef.lastWrittenPTS }
    micAudioWriter?.setVideoPTSProvider { videoRef.lastWrittenPTS }

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
}
