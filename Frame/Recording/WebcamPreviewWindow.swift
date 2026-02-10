import AppKit
import AVFoundation

@MainActor
final class WebcamPreviewWindow {
  private var panel: NSPanel?
  private var previewLayer: AVCaptureVideoPreviewLayer?

  func show(captureSession: AVCaptureSession) {
    guard panel == nil else { return }

    let width: CGFloat = 180
    let height: CGFloat = 135

    guard let screen = NSScreen.main else { return }
    let screenFrame = screen.visibleFrame
    let origin = CGPoint(
      x: screenFrame.maxX - width - 20,
      y: screenFrame.minY + 20
    )

    let panel = NSPanel(
      contentRect: NSRect(origin: origin, size: NSSize(width: width, height: height)),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.level = .floating
    panel.isFloatingPanel = true
    panel.isMovableByWindowBackground = true
    panel.hasShadow = true
    panel.backgroundColor = .black
    panel.isOpaque = false
    panel.sharingType = .none

    let contentView = NSView(frame: NSRect(origin: .zero, size: NSSize(width: width, height: height)))
    contentView.wantsLayer = true
    contentView.layer?.cornerRadius = 10
    contentView.layer?.masksToBounds = true

    let layer = AVCaptureVideoPreviewLayer(session: captureSession)
    layer.videoGravity = .resizeAspectFill
    layer.frame = contentView.bounds
    layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
    contentView.layer?.addSublayer(layer)
    self.previewLayer = layer

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
