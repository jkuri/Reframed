import CoreMedia
import Foundation

extension RecordingCoordinator {
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

    await systemAudioCapture?.stop()
    systemAudioCapture = nil

    await captureSession?.stop()
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
      captureQuality: captureQualityUsed,
      isHDR: hdrCaptureUsed
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

    await systemAudioCapture?.stop()
    systemAudioCapture = nil

    await captureSession?.stop()
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
}
