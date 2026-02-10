import AVFoundation
import AppKit
import SwiftUI

struct VideoPreviewView: NSViewRepresentable {
  let screenPlayer: AVPlayer
  let webcamPlayer: AVPlayer?
  @Binding var pipLayout: PiPLayout
  let webcamSize: CGSize?
  let screenSize: CGSize

  func makeNSView(context: Context) -> VideoPreviewContainer {
    let container = VideoPreviewContainer()
    container.screenPlayerLayer.player = screenPlayer
    if let webcam = webcamPlayer {
      container.webcamPlayerLayer.player = webcam
      container.webcamPlayerLayer.isHidden = false
    }
    container.coordinator = context.coordinator
    return container
  }

  func updateNSView(_ nsView: VideoPreviewContainer, context: Context) {
    nsView.updatePiPLayout(pipLayout, webcamSize: webcamSize, screenSize: screenSize)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(pipLayout: $pipLayout, screenSize: screenSize, webcamSize: webcamSize)
  }

  final class Coordinator {
    var pipLayout: Binding<PiPLayout>
    let screenSize: CGSize
    let webcamSize: CGSize?
    var isDragging = false
    var isResizing = false
    var dragStart: CGPoint = .zero
    var startLayout: PiPLayout = PiPLayout()

    init(pipLayout: Binding<PiPLayout>, screenSize: CGSize, webcamSize: CGSize?) {
      self.pipLayout = pipLayout
      self.screenSize = screenSize
      self.webcamSize = webcamSize
    }
  }
}

final class VideoPreviewContainer: NSView {
  let screenPlayerLayer = AVPlayerLayer()
  let webcamPlayerLayer = AVPlayerLayer()
  private let webcamView = WebcamPiPView()
  var coordinator: VideoPreviewView.Coordinator?
  private let resizeHandleSize: CGFloat = 12

  override init(frame: NSRect) {
    super.init(frame: frame)
    wantsLayer = true
    layer?.backgroundColor = NSColor.black.cgColor

    screenPlayerLayer.videoGravity = .resizeAspect
    layer?.addSublayer(screenPlayerLayer)

    webcamView.wantsLayer = true
    webcamView.layer?.cornerRadius = 8
    webcamView.layer?.masksToBounds = true
    webcamView.layer?.borderWidth = 1
    webcamView.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
    webcamPlayerLayer.videoGravity = .resizeAspectFill
    webcamView.layer?.addSublayer(webcamPlayerLayer)
    webcamPlayerLayer.isHidden = true
    addSubview(webcamView)
  }

  required init?(coder: NSCoder) { nil }

  override func layout() {
    super.layout()
    screenPlayerLayer.frame = bounds
    webcamPlayerLayer.frame = webcamView.bounds
  }

  func updatePiPLayout(_ layout: PiPLayout, webcamSize: CGSize?, screenSize: CGSize) {
    guard let ws = webcamSize, webcamPlayerLayer.player != nil else {
      webcamView.isHidden = true
      return
    }
    webcamView.isHidden = false

    let videoRect = AVMakeRect(aspectRatio: screenSize, insideRect: bounds)
    let aspect = ws.height / max(ws.width, 1)
    let w = videoRect.width * layout.relativeWidth
    let h = w * aspect
    let x = videoRect.origin.x + videoRect.width * layout.relativeX
    let y = videoRect.origin.y + videoRect.height * layout.relativeY

    webcamView.frame = CGRect(x: x, y: bounds.height - y - h, width: w, height: h)
    webcamPlayerLayer.frame = webcamView.bounds
  }

  override func mouseDown(with event: NSEvent) {
    guard let coord = coordinator else { return super.mouseDown(with: event) }
    let loc = convert(event.locationInWindow, from: nil)

    if webcamView.frame.contains(loc) && !webcamView.isHidden {
      let handleRect = CGRect(
        x: webcamView.frame.maxX - resizeHandleSize,
        y: webcamView.frame.minY,
        width: resizeHandleSize,
        height: resizeHandleSize
      )
      if handleRect.contains(loc) {
        coord.isResizing = true
      } else {
        coord.isDragging = true
      }
      coord.dragStart = loc
      coord.startLayout = coord.pipLayout.wrappedValue
    } else {
      super.mouseDown(with: event)
    }
  }

  override func mouseDragged(with event: NSEvent) {
    guard let coord = coordinator else { return super.mouseDragged(with: event) }
    let loc = convert(event.locationInWindow, from: nil)
    let videoRect = AVMakeRect(aspectRatio: coord.screenSize, insideRect: bounds)
    guard videoRect.width > 0 && videoRect.height > 0 else { return }

    if coord.isDragging {
      let dx = (loc.x - coord.dragStart.x) / videoRect.width
      let dy = -(loc.y - coord.dragStart.y) / videoRect.height
      var newX = coord.startLayout.relativeX + dx
      var newY = coord.startLayout.relativeY + dy

      let relW = coord.pipLayout.wrappedValue.relativeWidth
      let relH: CGFloat = {
        guard let ws = coord.webcamSize else { return relW * 0.75 }
        let aspect = ws.height / max(ws.width, 1)
        return relW * aspect * (coord.screenSize.width / max(coord.screenSize.height, 1))
      }()

      newX = max(0, min(1 - relW, newX))
      newY = max(0, min(1 - relH, newY))

      let snapDistX: CGFloat = 20 / videoRect.width
      let snapDistY: CGFloat = 20 / videoRect.height
      if newX < snapDistX { newX = 0.02 }
      if newX > 1 - relW - snapDistX { newX = 1 - relW - 0.02 }
      if newY < snapDistY { newY = 0.02 }
      if newY > 1 - relH - snapDistY { newY = 1 - relH - 0.02 }

      coord.pipLayout.wrappedValue.relativeX = newX
      coord.pipLayout.wrappedValue.relativeY = newY
    } else if coord.isResizing {
      let dx = (loc.x - coord.dragStart.x) / videoRect.width
      var newW = coord.startLayout.relativeWidth + dx
      newW = max(0.1, min(0.5, newW))
      coord.pipLayout.wrappedValue.relativeWidth = newW
    }
  }

  override func mouseUp(with event: NSEvent) {
    coordinator?.isDragging = false
    coordinator?.isResizing = false
    super.mouseUp(with: event)
  }
}

private final class WebcamPiPView: NSView {
  override var isFlipped: Bool { true }
}
