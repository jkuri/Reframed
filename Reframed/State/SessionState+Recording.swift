import AVFoundation
import AppKit
import Foundation
import ScreenCaptureKit

@MainActor
extension SessionState {
  func beginRecordingWithCountdown() {
    Task {
      do {
        try await startRecording()
      } catch {
        logger.error("Failed to start recording: \(error)")
        cleanupAfterRecordingFailure()
        showError(error.localizedDescription)
      }
    }
  }

  func cleanupAfterRecordingFailure() {
    mouseClickMonitor?.stop()
    mouseClickMonitor = nil
    cursorMetadataRecorder?.stop()
    cursorMetadataRecorder = nil
    cleanupCoordinators()
    devicePreviewWindow?.close()
    devicePreviewWindow = nil
    deviceCapture?.stop()
    deviceCapture = nil
    captureTarget = nil
    transition(to: .idle)
  }

  func startRecording() async throws {
    switch state {
    case .selecting, .idle, .countdown:
      break
    default:
      throw CaptureError.invalidTransition(from: "\(state)", to: "recording")
    }

    if captureMode == .device, let capture = deviceCapture {
      try await startDeviceRecordingInternal(capture: capture)
      return
    }

    guard let target = captureTarget else {
      throw CaptureError.noSelectionStored
    }

    let coordinator = RecordingCoordinator()
    await coordinator.setStreamErrorHandler { [weak self] _ in
      guard let self else { return }
      Task { @MainActor in await self.handleStreamError() }
    }
    await coordinator.setDeviceLostHandler { [weak self] device in
      guard let self else { return }
      Task { @MainActor in self.handleDeviceLost(device) }
    }
    self.recordingCoordinator = coordinator
    overlayView = nil

    let useCam = isCameraOn && options.selectedCamera != nil
    let useMic = isMicrophoneOn && options.selectedMicrophone != nil

    let metadataRecorder = CursorMetadataRecorder()
    self.cursorMetadataRecorder = metadataRecorder

    SoundEffect.startRecording.play()

    let startedAt = try await coordinator.startRecording(
      target: target,
      fps: options.fps,
      captureSystemAudio: options.captureSystemAudio,
      microphoneDeviceId: useMic ? options.selectedMicrophone?.id : nil,
      cameraDeviceId: useCam ? options.selectedCamera?.id : nil,
      cameraResolution: ConfigService.shared.cameraMaximumResolution,
      existingWebcam: attachExistingWebcam(),
      cursorMetadataRecorder: metadataRecorder,
      captureQuality: options.captureQuality,
      retinaCapture: options.retinaCapture,
      hdrCapture: options.hdrCapture
    )

    metadataRecorder.start()

    let box = await coordinator.getWebcamCaptureSessionBox()
    showCameraPreviewIfNeeded(from: box)

    let monitor = MouseClickMonitor(metadataRecorder: metadataRecorder)
    monitor.start()
    mouseClickMonitor = monitor

    await startRecordingPreview(coordinator: coordinator)
    transition(to: .recording(startedAt: startedAt))
  }

  private func startDeviceRecordingInternal(capture: DeviceCapture) async throws {
    let coordinator = RecordingCoordinator()
    await coordinator.setStreamErrorHandler { [weak self] _ in
      guard let self else { return }
      Task { @MainActor in await self.handleStreamError() }
    }
    await coordinator.setDeviceLostHandler { [weak self] device in
      guard let self else { return }
      Task { @MainActor in self.handleDeviceLost(device) }
    }
    self.recordingCoordinator = coordinator
    overlayView = nil

    let useCam = isCameraOn && options.selectedCamera != nil
    let useMic = isMicrophoneOn && options.selectedMicrophone != nil

    SoundEffect.startRecording.play()

    let startedAt = try await coordinator.startDeviceRecording(
      deviceCapture: capture,
      fps: options.fps,
      microphoneDeviceId: useMic ? options.selectedMicrophone?.id : nil,
      cameraDeviceId: useCam ? options.selectedCamera?.id : nil,
      cameraResolution: ConfigService.shared.cameraMaximumResolution,
      existingWebcam: attachExistingWebcam(),
      captureQuality: options.captureQuality,
      retinaCapture: options.retinaCapture,
      hdrCapture: options.hdrCapture
    )

    let box = await coordinator.getWebcamCaptureSessionBox()
    showCameraPreviewIfNeeded(from: box)

    await startRecordingPreview(coordinator: coordinator)
    transition(to: .recording(startedAt: startedAt))
  }

  func stopRecording() async throws {
    switch state {
    case .recording, .paused:
      break
    default:
      throw CaptureError.invalidTransition(from: "\(state)", to: "processing")
    }

    mouseClickMonitor?.stop()
    mouseClickMonitor = nil
    cursorMetadataRecorder = nil
    recordingPreviewWindow?.close()
    recordingPreviewWindow = nil

    transition(to: .processing)
    cleanupCoordinators()

    let sourceName = projectSourceName()

    guard let result = try await recordingCoordinator?.stopRecordingRaw(keepWebcamAlive: false) else {
      recordingCoordinator = nil
      captureTarget = nil
      captureMode = .none
      stopCameraPreview()
      isCameraOn = false
      SoundEffect.stopRecording.play()
      transition(to: .idle)
      showToolbar()
      return
    }

    SoundEffect.stopRecording.play()
    recordingCoordinator = nil
    captureTarget = nil
    stopCameraPreview()
    isCameraOn = false
    devicePreviewWindow?.close()
    devicePreviewWindow = nil
    deviceCapture?.stop()
    deviceCapture = nil
    deviceName = nil

    let saveDir = FileManager.default.projectSaveDirectory()
    do {
      let project = try ReframedProject.create(
        from: result,
        fps: result.fps,
        captureMode: captureMode,
        sourceName: sourceName,
        in: saveDir
      )
      openEditor(project: project)
    } catch {
      logger.error("Failed to create project bundle: \(error)")
      openEditor(project: nil, result: result)
    }
  }

  func pauseRecording() {
    guard case .recording(let startedAt) = state else { return }
    let elapsed = Date().timeIntervalSince(startedAt)
    mouseClickMonitor?.stop()
    Task {
      await recordingCoordinator?.pause()
      SoundEffect.pauseRecording.play()
    }
    transition(to: .paused(elapsed: elapsed))
  }

  func resumeRecording() {
    guard case .paused(let elapsed) = state else { return }
    let resumedAt = Date().addingTimeInterval(-elapsed)
    mouseClickMonitor?.start()
    Task {
      SoundEffect.resumeRecording.play()
      await recordingCoordinator?.resume()
    }
    transition(to: .recording(startedAt: resumedAt))
  }

  func restartRecording() {
    mouseClickMonitor?.stop()
    mouseClickMonitor = nil

    let savedTarget = captureTarget
    let savedMode = captureMode
    let keepWebcam = persistentWebcam != nil

    Task {
      cleanupCoordinators()
      recordingPreviewWindow?.close()
      recordingPreviewWindow = nil
      if !keepWebcam {
        webcamPreviewWindow?.close()
        webcamPreviewWindow = nil
      }
      for editor in editorWindows { editor.close() }
      editorWindows.removeAll()

      if let url = try? await recordingCoordinator?.stopRecording(keepWebcamAlive: keepWebcam) {
        try? FileManager.default.removeItem(at: url)
        logger.info("Discarded recording: \(url.path)")
      }
      recordingCoordinator = nil
      FileManager.default.cleanupTempDir()

      captureTarget = savedTarget
      captureMode = savedMode
      transition(to: .idle)

      guard savedTarget != nil else { return }

      if case .region(let sel) = savedTarget {
        let coordinator = SelectionCoordinator()
        selectionCoordinator = coordinator
        coordinator.showRecordingBorder(screenRect: sel.rect)
      } else if case .window(let win) = savedTarget {
        let scFrame = win.frame
        let screenHeight = NSScreen.primaryScreenHeight
        let appKitRect = CGRect(
          x: scFrame.origin.x,
          y: screenHeight - scFrame.origin.y - scFrame.height,
          width: scFrame.width,
          height: scFrame.height
        )
        let coordinator = SelectionCoordinator()
        selectionCoordinator = coordinator
        coordinator.showRecordingBorder(screenRect: appKitRect)
      }

      beginRecordingWithCountdown()
    }
  }

  func startDeviceRecordingWith(deviceId: String) {
    guard case .idle = state else { return }

    let devices = DeviceDiscovery.shared.availableDevices
    guard let device = devices.first(where: { $0.id == deviceId }) else {
      showError(CaptureError.deviceNotFound.localizedDescription)
      return
    }

    let capture = DeviceCapture()
    deviceCapture = capture
    deviceName = device.name

    Task {
      do {
        let info = try await capture.startAndVerify(deviceId: device.id)
        guard captureMode == .device else {
          capture.stop()
          deviceCapture = nil
          return
        }

        if let session = capture.captureSession {
          let previewWindow = DevicePreviewWindow()
          previewWindow.show(
            captureSession: session,
            deviceName: device.name,
            delay: options.timerDelay.rawValue,
            onCountdownStart: { [weak self] in
              self?.toolbarWindow?.orderOut(nil)
            },
            onCancel: { [weak self] in self?.cancelSelection() },
            onStart: { [weak self] in self?.startDeviceRecording() }
          )
          devicePreviewWindow = previewWindow
        }

        hideToolbar()
        logger.info("Device preview started: \(device.name) at \(info.width)x\(info.height)")
      } catch {
        logger.error("Device recording failed: \(error)")
        deviceCapture?.stop()
        deviceCapture = nil
        showError(error.localizedDescription)
      }
    }
  }

  func startDeviceRecording() {
    devicePreviewWindow?.hideButton()
    beginRecordingWithCountdown()
  }

  func recordEntireScreen(screen: NSScreen) {
    guard Permissions.hasScreenRecordingPermission else {
      Permissions.requestScreenRecordingPermission()
      return
    }

    let selection = SelectionRect(rect: screen.frame, displayID: screen.displayID)
    captureTarget = .region(selection)

    let coordinator = SelectionCoordinator()
    selectionCoordinator = coordinator
    coordinator.showRecordingBorder(screenRect: screen.frame)

    beginRecordingWithCountdown()
  }

  func startRecordingPreview(coordinator: RecordingCoordinator) async {
    guard options.showRecordingPreview else { return }

    let dims = await coordinator.getVideoDimensions()
    let previewWindow = RecordingPreviewWindow()
    previewWindow.show(width: dims.width, height: dims.height)
    self.recordingPreviewWindow = previewWindow

    await coordinator.setPreviewFrameHandler { [weak previewWindow] sampleBuffer in
      previewWindow?.updateFrame(sampleBuffer)
    }
  }

  func handleDeviceLost(_ device: String) {
    logger.warning("\(device) disconnected during recording, continuing without it")
    if device == "camera" {
      webcamPreviewWindow?.close()
      webcamPreviewWindow = nil
      isCameraOn = false
    }
    if device == "microphone" {
      isMicrophoneOn = false
    }
  }

  func handleStreamError() async {
    switch state {
    case .recording, .paused:
      logger.warning("Stream stopped unexpectedly, stopping recording")
      await recordingCoordinator?.pause()
      do {
        try await stopRecording()
      } catch {
        logger.error("Failed to stop recording after stream error: \(error)")
        recordingCoordinator = nil
        captureTarget = nil
        captureMode = .none
        stopCameraPreview()
        isCameraOn = false
        transition(to: .idle)
        showToolbar()
      }
    default:
      break
    }
  }
}
