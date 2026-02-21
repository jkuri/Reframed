import AVFoundation
import AppKit
import SwiftUI

struct DeviceStartRecordingView: View {
  let delay: Int
  let onCountdownStart: () -> Void
  let onCancel: () -> Void
  let onStart: () -> Void

  var body: some View {
    StartRecordingButton(
      delay: delay,
      onCountdownStart: onCountdownStart,
      onCancel: onCancel,
      action: onStart
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay {
      Button("") { onCancel() }
        .keyboardShortcut(.escape, modifiers: [])
        .opacity(0)
    }
  }
}

@MainActor
final class DevicePreviewPanel: NSPanel {
  init(origin: CGPoint, size: NSSize) {
    super.init(
      contentRect: NSRect(origin: origin, size: size),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}

@MainActor
final class DevicePreviewWindow {
  private var panel: DevicePreviewPanel?
  private var previewLayer: AVCaptureVideoPreviewLayer?
  nonisolated(unsafe) private var moveObserver: NSObjectProtocol?
  private var appearanceObserver: NSKeyValueObservation?

  private let padding: CGFloat = 6
  private let videoWidth: CGFloat = 270
  private let videoHeight: CGFloat = 585
  private let cornerRadius: CGFloat = 14
  private let buttonAreaHeight: CGFloat = 64

  private var totalWidth: CGFloat { videoWidth + padding * 2 }
  private var totalHeight: CGFloat { videoHeight + padding * 2 + buttonAreaHeight }

  func show(
    captureSession: AVCaptureSession,
    deviceName: String,
    delay: Int,
    onCountdownStart: @escaping () -> Void,
    onCancel: @escaping () -> Void,
    onStart: @escaping () -> Void
  ) {
    if panel == nil {
      createPanel()
    }

    previewLayer?.removeFromSuperlayer()
    previewLayer = nil

    guard let contentView = panel?.contentView else { return }
    contentView.subviews.removeAll()

    let videoView = NSView(
      frame: NSRect(x: padding, y: padding + buttonAreaHeight, width: videoWidth, height: videoHeight)
    )
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

    let buttonContent = DeviceStartRecordingView(
      delay: delay,
      onCountdownStart: onCountdownStart,
      onCancel: onCancel,
      onStart: onStart
    )
    let hostingView = NSHostingView(rootView: buttonContent)
    hostingView.frame = NSRect(x: 0, y: 0, width: totalWidth, height: buttonAreaHeight)
    contentView.addSubview(hostingView)

    panel?.title = deviceName
    panel?.makeKeyAndOrderFront(nil)
  }

  func hideButton() {
    guard let contentView = panel?.contentView else { return }
    for subview in contentView.subviews where subview is NSHostingView<DeviceStartRecordingView> {
      subview.removeFromSuperview()
    }
    let videoOnlyHeight = videoHeight + padding * 2
    for subview in contentView.subviews {
      subview.frame.origin.y = padding
    }
    contentView.frame.size.height = videoOnlyHeight
    guard let panel else { return }
    var frame = panel.frame
    let heightDiff = frame.height - videoOnlyHeight
    frame.origin.y += heightDiff
    frame.size.height = videoOnlyHeight
    panel.setFrame(frame, display: true)
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

    let panel = DevicePreviewPanel(
      origin: origin,
      size: NSSize(width: totalWidth, height: totalHeight)
    )
    panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
    panel.isFloatingPanel = true
    panel.isMovableByWindowBackground = true
    panel.hasShadow = true
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.sharingType = Window.sharingType
    panel.collectionBehavior = [.canJoinAllSpaces]

    let contentView = NSView(
      frame: NSRect(origin: .zero, size: NSSize(width: totalWidth, height: totalHeight))
    )
    contentView.wantsLayer = true
    contentView.layer?.cornerRadius = cornerRadius
    contentView.layer?.masksToBounds = true
    contentView.layer?.backgroundColor = ReframedColors.backgroundNS.cgColor
    contentView.layer?.borderWidth = 1
    contentView.layer?.borderColor = ReframedColors.borderNS.cgColor

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
    contentView.layer?.backgroundColor = ReframedColors.backgroundNS.cgColor
    contentView.layer?.borderColor = ReframedColors.borderNS.cgColor
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
