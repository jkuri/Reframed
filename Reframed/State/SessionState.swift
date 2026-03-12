import AppKit
import Foundation
import Logging
import ScreenCaptureKit
import SwiftUI

enum CameraPreviewState {
  case off
  case starting
  case previewing
  case failed(String)
}

@MainActor
@Observable
final class SessionState {
  var state: CaptureState = .idle
  var lastRecordingURL: URL?
  var captureMode: CaptureMode = .none
  var errorMessage: String?
  var cameraPreviewState: CameraPreviewState = .off
  var isCameraOn = false
  var isMicrophoneOn = false
  var micAudioLevel: Float = 0
  var systemAudioLevel: Float = 0
  let options = RecordingOptions()

  weak var statusItemButton: NSStatusBarButton?
  var menuBarIconState: MenuBarIcon.State = .idle

  init() {
    if ConfigService.shared.isMicrophoneOn, options.selectedMicrophone != nil {
      isMicrophoneOn = true
    }
  }

  let logger = Logger(label: "eu.jankuri.reframed.session")
  var selectionCoordinator: SelectionCoordinator?
  var windowSelectionCoordinator: WindowSelectionCoordinator?
  var recordingCoordinator: RecordingCoordinator?
  var captureTarget: CaptureTarget?
  var toolbarWindow: CaptureToolbarWindow?
  var startRecordingWindows: [StartRecordingWindow] = []
  var editorWindows: [EditorWindow] = []
  var webcamPreviewWindow: WebcamPreviewWindow?
  var persistentWebcam: WebcamCapture?
  var verifiedCameraInfo: VerifiedCamera?
  var mouseClickMonitor: MouseClickMonitor?
  var cursorMetadataRecorder: CursorMetadataRecorder?
  var recordingPreviewWindow: RecordingPreviewWindow?
  var devicePreviewWindow: DevicePreviewWindow?
  var deviceCapture: DeviceCapture?
  var deviceName: String?
  var audioLevelTask: Task<Void, Never>?
  var windowPositionObserver: WindowPositionObserver?
  var processingPulseTimer: Timer?
  var processingPulseOn = false

  weak var overlayView: SelectionOverlayView?

  func transition(to newState: CaptureState) {
    state = newState
    updateStatusIcon()

    switch newState {
    case .recording:
      if audioLevelTask == nil { startAudioLevelPolling() }
      if windowPositionObserver == nil, case .window(let win) = captureTarget {
        startWindowTracking(windowID: win.windowID)
      }
      if options.hideCameraPreviewWhileRecording {
        webcamPreviewWindow?.hide()
      }
      showToolbar()
      if case .window(let win) = captureTarget,
        let pid = win.owningApplication?.processID
      {
        focusWindow(pid: pid, frame: win.frame)
      }
    case .paused:
      if options.hideCameraPreviewWhileRecording {
        webcamPreviewWindow?.unhide()
      }
    default:
      webcamPreviewWindow?.unhide()
      stopAudioLevelPolling()
      stopWindowTracking()
    }
  }
}
