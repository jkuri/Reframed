import AVFoundation
import AppKit

@MainActor
final class WebcamPreviewWindow {
  private var panel: NSPanel?
  private var previewLayer: AVCaptureVideoPreviewLayer?
  private var loadingView: NSView?
  nonisolated(unsafe) private var moveObserver: NSObjectProtocol?
  private var appearanceObserver: NSKeyValueObservation?

  private let videoWidth: CGFloat = 270
  private let videoHeight: CGFloat = 202
  private let cornerRadius: CGFloat = 60

  private var totalWidth: CGFloat { videoWidth }
  private var totalHeight: CGFloat { videoHeight }

  func showLoading() {
    if panel == nil {
      createPanel()
    }

    previewLayer?.removeFromSuperlayer()
    previewLayer = nil
    loadingView?.removeFromSuperview()

    guard let contentView = panel?.contentView else { return }

    let container = NSView(frame: NSRect(origin: .zero, size: NSSize(width: videoWidth, height: videoHeight)))
    container.wantsLayer = true
    container.layer?.cornerRadius = cornerRadius
    container.layer?.masksToBounds = true
    container.layer?.backgroundColor = ReframedColors.panelBackgroundNS.cgColor

    let spinner = NSProgressIndicator(frame: NSRect(x: (videoWidth - 24) / 2, y: (videoHeight - 24) / 2 + 10, width: 24, height: 24))
    spinner.style = .spinning
    spinner.controlSize = .small
    spinner.appearance = NSAppearance(named: ReframedColors.isDark ? .darkAqua : .aqua)
    spinner.startAnimation(nil)
    container.addSubview(spinner)

    let label = NSTextField(labelWithString: "Camera is starting...")
    label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
    label.textColor = ReframedColors.secondaryTextNS
    label.alignment = .center
    label.frame = NSRect(x: 0, y: (videoHeight - 24) / 2 - 18, width: videoWidth, height: 16)
    container.addSubview(label)

    contentView.addSubview(container)
    loadingView = container

    panel?.orderFrontRegardless()
  }

  func show(captureSession: AVCaptureSession) {
    if panel == nil {
      createPanel()
    }

    previewLayer?.removeFromSuperlayer()
    previewLayer = nil

    guard let contentView = panel?.contentView else { return }

    let videoView = NSView(frame: NSRect(origin: .zero, size: NSSize(width: videoWidth, height: videoHeight)))
    videoView.wantsLayer = true
    videoView.layer?.cornerRadius = cornerRadius
    videoView.layer?.masksToBounds = true

    let layer = AVCaptureVideoPreviewLayer(session: captureSession)
    layer.videoGravity = .resizeAspectFill
    layer.frame = videoView.bounds
    layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
    videoView.layer?.addSublayer(layer)
    self.previewLayer = layer

    contentView.addSubview(videoView, positioned: .below, relativeTo: loadingView)
    panel?.orderFrontRegardless()

    let pendingLoadingView = loadingView
    loadingView = nil
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      pendingLoadingView?.removeFromSuperview()
    }
  }

  func showError(_ message: String) {
    if panel == nil {
      createPanel()
    }

    previewLayer?.removeFromSuperlayer()
    previewLayer = nil
    loadingView?.removeFromSuperview()
    loadingView = nil

    guard let contentView = panel?.contentView else { return }

    let container = NSView(frame: NSRect(origin: .zero, size: NSSize(width: videoWidth, height: videoHeight)))
    container.wantsLayer = true
    container.layer?.cornerRadius = cornerRadius
    container.layer?.masksToBounds = true
    container.layer?.backgroundColor = ReframedColors.panelBackgroundNS.cgColor

    let icon = NSImageView(frame: NSRect(x: (videoWidth - 24) / 2, y: (videoHeight - 24) / 2 + 10, width: 24, height: 24))
    icon.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Error")
    icon.contentTintColor = .systemOrange
    container.addSubview(icon)

    let label = NSTextField(labelWithString: message)
    label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
    label.textColor = ReframedColors.secondaryTextNS
    label.alignment = .center
    label.lineBreakMode = .byTruncatingTail
    label.frame = NSRect(x: 4, y: (videoHeight - 24) / 2 - 18, width: videoWidth - 8, height: 16)
    container.addSubview(label)

    contentView.addSubview(container)
    loadingView = container

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
    loadingView?.removeFromSuperview()
    loadingView = nil
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

    let contentView = NSView(frame: NSRect(origin: .zero, size: NSSize(width: totalWidth, height: totalHeight)))
    contentView.wantsLayer = true
    contentView.layer?.cornerRadius = cornerRadius
    contentView.layer?.masksToBounds = true
    contentView.layer?.backgroundColor = NSColor.clear.cgColor

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
    if let container = loadingView {
      container.layer?.backgroundColor = ReframedColors.panelBackgroundNS.cgColor
      for subview in container.subviews {
        if let label = subview as? NSTextField {
          label.textColor = ReframedColors.secondaryTextNS
        }
        if let spinner = subview as? NSProgressIndicator {
          spinner.appearance = NSAppearance(named: ReframedColors.isDark ? .darkAqua : .aqua)
        }
      }
    }
  }

  private func resolvedOrigin() -> CGPoint {
    if let saved = StateService.shared.webcamPreviewPosition {
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
      x: screenFrame.maxX - totalWidth - 20,
      y: screenFrame.minY + 20
    )
  }

  private func savePosition() {
    guard let frame = panel?.frame else { return }
    StateService.shared.webcamPreviewPosition = frame.origin
  }
}
