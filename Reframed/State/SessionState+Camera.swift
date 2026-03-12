import AppKit
import Foundation
import ScreenCaptureKit

@MainActor
extension SessionState {
  func toggleCamera() {
    guard options.selectedCamera != nil else { return }
    isCameraOn.toggle()
    if isCameraOn {
      startCameraPreview()
    } else {
      stopCameraPreview()
    }
  }

  private func startCameraPreview() {
    guard let cam = options.selectedCamera else { return }

    stopCameraPreview()
    cameraPreviewState = .starting

    let previewWindow = WebcamPreviewWindow()
    previewWindow.showLoading()
    webcamPreviewWindow = previewWindow

    Task {
      do {
        let (maxW, maxH) = CaptureMode.cameraMaxDimensions(for: ConfigService.shared.cameraMaximumResolution)
        let webcam = WebcamCapture()
        let info = try await webcam.startAndVerify(
          deviceId: cam.id,
          fps: options.fps,
          maxWidth: maxW,
          maxHeight: maxH
        )
        guard isCameraOn, options.selectedCamera?.id == cam.id else {
          webcam.stop()
          return
        }
        persistentWebcam = webcam
        verifiedCameraInfo = info
        cameraPreviewState = .previewing

        if let session = webcam.captureSession {
          previewWindow.show(captureSession: session)
        }
        logger.info("Camera preview started: \(info.width)x\(info.height)")
      } catch {
        guard isCameraOn, options.selectedCamera?.id == cam.id else { return }
        cameraPreviewState = .failed(error.localizedDescription)
        previewWindow.showError("Camera failed to start")
        logger.error("Camera preview failed: \(error)")
      }
    }
  }

  func stopCameraPreview() {
    persistentWebcam?.stop()
    persistentWebcam = nil
    verifiedCameraInfo = nil
    webcamPreviewWindow?.close()
    webcamPreviewWindow = nil
    cameraPreviewState = .off
  }

  func attachExistingWebcam() -> (WebcamCapture, VerifiedCamera)? {
    let useCam = isCameraOn && options.selectedCamera != nil
    if useCam, let webcam = persistentWebcam, let info = verifiedCameraInfo {
      return (webcam, info)
    }
    return nil
  }

  func showCameraPreviewIfNeeded(from box: SendableBox<AVCaptureSession>?) {
    if let camSession = box?.session {
      let previewWindow = WebcamPreviewWindow()
      previewWindow.show(captureSession: camSession)
      if options.hideCameraPreviewWhileRecording {
        previewWindow.hide()
      }
      self.webcamPreviewWindow = previewWindow
    }
  }
}
