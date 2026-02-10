import AppKit
import AVFoundation

@MainActor
final class WebcamPreviewWindow {
  private var panel: NSPanel?
  private var previewLayer: AVCaptureVideoPreviewLayer?

  func show(captureSession: AVCaptureSession) {
    guard panel == nil else { return }

    let padding: CGFloat = 6
    let videoWidth: CGFloat = 180
    let videoHeight: CGFloat = 135
    let totalWidth = videoWidth + padding * 2
    let totalHeight = videoHeight + padding * 2
    let cornerRadius: CGFloat = 14

    guard let screen = NSScreen.main else { return }
    let screenFrame = screen.visibleFrame
    let origin = CGPoint(
      x: screenFrame.maxX - totalWidth - 20,
      y: screenFrame.minY + 20
    )

    let panel = NSPanel(
      contentRect: NSRect(origin: origin, size: NSSize(width: totalWidth, height: totalHeight)),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.level = .floating
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
    contentView.layer?.backgroundColor = NSColor(white: 0.15, alpha: 1).cgColor
    contentView.layer?.borderWidth = 1
    contentView.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor

    let videoView = NSView(frame: NSRect(x: padding, y: padding, width: videoWidth, height: videoHeight))
    videoView.wantsLayer = true
    videoView.layer?.cornerRadius = cornerRadius - 3
    videoView.layer?.masksToBounds = true

    let layer = AVCaptureVideoPreviewLayer(session: captureSession)
    layer.videoGravity = .resizeAspectFill
    layer.frame = videoView.bounds
    layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
    videoView.layer?.addSublayer(layer)
    self.previewLayer = layer

    contentView.addSubview(videoView)
    panel.contentView = contentView
    panel.orderFrontRegardless()

    self.panel = panel
  }

  func close() {
    previewLayer?.removeFromSuperlayer()
    previewLayer = nil
    panel?.orderOut(nil)
    panel?.contentView = nil
    panel = nil
  }
}
