import AppKit

@MainActor
final class WindowPositionObserver {
  nonisolated(unsafe) private var displayLink: CADisplayLink?
  private let windowID: CGWindowID
  private var lastRect: CGRect = .zero
  private let onChange: (CGRect) -> Void

  init(windowID: CGWindowID, onChange: @escaping @MainActor (CGRect) -> Void) {
    self.windowID = windowID
    self.onChange = onChange

    guard let screen = NSScreen.screens.first else { return }
    let target = DisplayLinkTarget(observer: self)
    let link = screen.displayLink(target: target, selector: #selector(DisplayLinkTarget.step))
    link.add(to: .main, forMode: .common)
    self.displayLink = link
  }

  deinit {
    displayLink?.invalidate()
  }

  func stop() {
    displayLink?.invalidate()
    displayLink = nil
  }

  fileprivate func tick() {
    guard
      let list = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]],
      let info = list.first,
      let boundsDict = info[kCGWindowBounds as String],
      let bounds = CGRect(dictionaryRepresentation: boundsDict as! CFDictionary)
    else { return }

    let screenHeight = NSScreen.primaryScreenHeight
    let appKitRect = CGRect(
      x: bounds.origin.x,
      y: screenHeight - bounds.origin.y - bounds.height,
      width: bounds.width,
      height: bounds.height
    )

    guard appKitRect != lastRect else { return }
    lastRect = appKitRect
    onChange(appKitRect)
  }
}

@MainActor
private final class DisplayLinkTarget: NSObject {
  private weak var observer: WindowPositionObserver?

  init(observer: WindowPositionObserver) {
    self.observer = observer
  }

  @objc func step() {
    observer?.tick()
  }
}
