import AVFoundation
import AppKit

@MainActor
final class DevicePreviewWindow {
  private var panel: NSPanel?
  private var previewLayer: AVCaptureVideoPreviewLayer?
  nonisolated(unsafe) private var moveObserver: NSObjectProtocol?
  private var appearanceObserver: NSKeyValueObservation?

  private let padding: CGFloat = 6
  private let videoWidth: CGFloat = 270
  private let videoHeight: CGFloat = 585
  private let cornerRadius: CGFloat = 14

  private var totalWidth: CGFloat { videoWidth + padding * 2 }
  private var totalHeight: CGFloat { videoHeight + padding * 2 }

  func show(captureSession: AVCaptureSession, deviceName: String) {
    if panel == nil {
      createPanel()
    }

    previewLayer?.removeFromSuperlayer()
    previewLayer = nil

    guard let contentView = panel?.contentView else { return }

    let videoView = NSView(frame: NSRect(x: padding, y: padding, width: videoWidth, height: videoHeight))
    videoView.wantsLayer = true
    videoView.layer?.cornerRadius = cornerRadius - 3
    videoView.layer?.masksToBounds = true

    let layer = AVCaptureVideoPreviewLayer(session: captureSession)
    layer.videoGravity = .resizeAspect
    layer.frame = videoView.bounds
    layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
    videoView.layer?.addSublayer(layer)
    self.previewLayer = layer

    contentView.addSubview(videoView)
    panel?.title = deviceName
    panel?.orderFrontRegardless()
  }

  func close() {
    savePosition()
    if let observer = moveObserver {
      NotificationCenter.default.removeObserver(observer)
      moveObserver = nil
    }
    appearanceObserver?.invalidate()
    appearanceObserver = nil
    previewLayer?.removeFromSuperlayer()
    previewLayer = nil
    panel?.orderOut(nil)
    panel?.contentView = nil
    panel = nil
  }

  private func createPanel() {
    let origin = resolvedOrigin()

    let panel = NSPanel(
      contentRect: NSRect(origin: origin, size: NSSize(width: totalWidth, height: totalHeight)),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
    panel.isFloatingPanel = true
    panel.isMovableByWindowBackground = true
    panel.hasShadow = true
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.sharingType = .none
    panel.collectionBehavior = [.canJoinAllSpaces]

    let contentView = NSView(frame: NSRect(origin: .zero, size: NSSize(width: totalWidth, height: totalHeight)))
    contentView.wantsLayer = true
    contentView.layer?.cornerRadius = cornerRadius
    contentView.layer?.masksToBounds = true
    contentView.layer?.backgroundColor = FrameColors.panelBackgroundNS.cgColor
    contentView.layer?.borderWidth = 1
    contentView.layer?.borderColor = FrameColors.subtleBorderNS.cgColor

    panel.contentView = contentView
    self.panel = panel

    moveObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didMoveNotification,
      object: panel,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.savePosition()
      }
    }

    appearanceObserver = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
      MainActor.assumeIsolated {
        self?.updateColors()
      }
    }
  }

  private func updateColors() {
    guard let contentView = panel?.contentView else { return }
    contentView.layer?.backgroundColor = FrameColors.panelBackgroundNS.cgColor
    contentView.layer?.borderColor = FrameColors.subtleBorderNS.cgColor
  }

  private func resolvedOrigin() -> CGPoint {
    if let saved = StateService.shared.devicePreviewPosition {
      let panelRect = NSRect(origin: saved, size: NSSize(width: totalWidth, height: totalHeight))
      for screen in NSScreen.screens {
        if screen.visibleFrame.intersects(panelRect) {
          return saved
        }
      }
    }
    return defaultOrigin()
  }

  private func defaultOrigin() -> CGPoint {
    guard let screen = NSScreen.main else { return .zero }
    let screenFrame = screen.visibleFrame
    return CGPoint(
      x: screenFrame.midX - totalWidth / 2,
      y: screenFrame.midY - totalHeight / 2
    )
  }

  private func savePosition() {
    guard let frame = panel?.frame else { return }
    StateService.shared.devicePreviewPosition = frame.origin
  }
}
