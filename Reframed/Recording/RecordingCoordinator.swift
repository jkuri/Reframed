import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import Logging
@preconcurrency import ScreenCaptureKit

actor RecordingCoordinator {
  var captureSession: ScreenCaptureSession?
  var systemAudioCapture: SystemAudioCapture?
  var microphoneCapture: MicrophoneCapture?
  var webcamCapture: WebcamCapture?
  var deviceCapture: DeviceCapture?
  var deviceAudioWriter: AudioTrackWriter?
  var videoWriter: VideoTrackWriter?
  var webcamWriter: VideoTrackWriter?
  var systemAudioWriter: AudioTrackWriter?
  var micAudioWriter: AudioTrackWriter?
  var recordingClock: SharedRecordingClock?
  var cursorMetadataRecorder: CursorMetadataRecorder?
  let logger = Logger(label: "eu.jankuri.reframed.recording-coordinator")
  var onStreamError: (@Sendable (any Error) -> Void)?
  var onDeviceLost: (@Sendable (String) -> Void)?
  var pauseStartTime: CMTime = .invalid
  var totalPauseOffset: CMTime = .zero
  var pixelW: Int = 0
  var pixelH: Int = 0
  var webcamPixelW: Int = 0
  var webcamPixelH: Int = 0
  var recordingFPS: Int = 60
  var captureQualityUsed: CaptureQuality = .standard
  var hdrCaptureUsed: Bool = false

  func setStreamErrorHandler(_ handler: @escaping @Sendable (any Error) -> Void) {
    onStreamError = handler
  }

  func setDeviceLostHandler(_ handler: @escaping @Sendable (String) -> Void) {
    onDeviceLost = handler
  }

  func handleStreamError(_ error: any Error) {
    logger.error("Stream error received: \(error.localizedDescription)")
    onStreamError?(error)
  }

  func handleDeviceLost(_ device: String) {
    logger.warning("\(device) disconnected during recording")
    onDeviceLost?(device)
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

  func setPreviewFrameHandler(_ handler: @escaping @Sendable (CMSampleBuffer) -> Void) {
    captureSession?.onPreviewFrame = handler
    deviceCapture?.onPreviewFrame = handler
  }

  func getVideoDimensions() -> (width: Int, height: Int) {
    (pixelW, pixelH)
  }

}
