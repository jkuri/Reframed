import AppKit
import QuartzCore

@MainActor
final class MouseClickWindow: NSPanel {
  fileprivate static let animationDuration: CFTimeInterval = 0.4

  private let endDiameter: CGFloat
  private let startDiameter: CGFloat
  private let clickColor: NSColor

  init(at screenPoint: NSPoint, color: NSColor, size: CGFloat) {
    endDiameter = size
    startDiameter = size * 0.44
    clickColor = color

    let windowSize = size + 4
    let origin = NSPoint(
      x: screenPoint.x - windowSize / 2,
      y: screenPoint.y - windowSize / 2
    )

    super.init(
      contentRect: NSRect(origin: origin, size: NSSize(width: windowSize, height: windowSize)),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    isOpaque = false
    backgroundColor = .clear
    level = .screenSaver
    ignoresMouseEvents = true
    hasShadow = false
    hidesOnDeactivate = false
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

    let clickView = MouseClickView(
      frame: NSRect(origin: .zero, size: NSSize(width: windowSize, height: windowSize)),
      startDiameter: startDiameter,
      endDiameter: endDiameter,
      color: clickColor
    )
    contentView = clickView
    orderFrontRegardless()
    clickView.animate { [weak self] in
      MainActor.assumeIsolated {
        self?.orderOut(nil)
        self?.contentView = nil
      }
    }
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

private final class MouseClickView: NSView {
  private let ringLayer = CAShapeLayer()
  private let fillLayer = CAShapeLayer()
  private let startDiameter: CGFloat
  private let endDiameter: CGFloat
  private let color: NSColor

  init(frame: NSRect, startDiameter: CGFloat, endDiameter: CGFloat, color: NSColor) {
    self.startDiameter = startDiameter
    self.endDiameter = endDiameter
    self.color = color
    super.init(frame: frame)
    wantsLayer = true
    layer?.masksToBounds = false

    let center = CGPoint(x: frame.width / 2, y: frame.height / 2)
    let startRadius = startDiameter / 2
    let startPath = CGPath(
      ellipseIn: CGRect(
        x: center.x - startRadius,
        y: center.y - startRadius,
        width: startDiameter,
        height: startDiameter
      ),
      transform: nil
    )

    let accentColor = color.cgColor

    fillLayer.path = startPath
    fillLayer.fillColor = accentColor.copy(alpha: 0.3)
    fillLayer.strokeColor = nil
    layer?.addSublayer(fillLayer)

    ringLayer.path = startPath
    ringLayer.fillColor = nil
    ringLayer.strokeColor = accentColor
    ringLayer.lineWidth = 2
    layer?.addSublayer(ringLayer)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  func animate(completion: @escaping @Sendable () -> Void) {
    let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
    let endRadius = endDiameter / 2
    let endPath = CGPath(
      ellipseIn: CGRect(
        x: center.x - endRadius,
        y: center.y - endRadius,
        width: endDiameter,
        height: endDiameter
      ),
      transform: nil
    )

    let duration = MouseClickWindow.animationDuration

    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    CATransaction.setAnimationDuration(duration)
    CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))

    let pathAnim = CABasicAnimation(keyPath: "path")
    pathAnim.toValue = endPath
    pathAnim.duration = duration
    pathAnim.fillMode = .forwards
    pathAnim.isRemovedOnCompletion = false

    let ringOpacity = CABasicAnimation(keyPath: "opacity")
    ringOpacity.toValue = 0
    ringOpacity.duration = duration
    ringOpacity.fillMode = .forwards
    ringOpacity.isRemovedOnCompletion = false

    let fillOpacity = CABasicAnimation(keyPath: "opacity")
    fillOpacity.toValue = 0
    fillOpacity.duration = duration
    fillOpacity.fillMode = .forwards
    fillOpacity.isRemovedOnCompletion = false

    ringLayer.add(pathAnim, forKey: "expand")
    ringLayer.add(ringOpacity, forKey: "fade")
    fillLayer.add(pathAnim, forKey: "expand")
    fillLayer.add(fillOpacity, forKey: "fade")

    CATransaction.commit()
  }
}
