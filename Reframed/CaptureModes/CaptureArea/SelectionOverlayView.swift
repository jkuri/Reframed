import AppKit
import SwiftUI

@MainActor
final class SelectionOverlayView: NSView {
  private let session: SessionState

  private var selectionRect: CGRect?
  private var dragOrigin: CGPoint?
  private var isDragging = false
  private var activeHandle: ResizeHandle?
  private var handleDragStart: CGPoint?
  private var originalRectBeforeResize: CGRect?
  private var mouseLocation: CGPoint = .zero
  private var controlsHost: NSHostingView<CaptureAreaView>?

  override var acceptsFirstResponder: Bool { true }
  override var isFlipped: Bool { false }

  init(frame: NSRect, session: SessionState) {
    self.session = session
    super.init(frame: frame)
  }

  required init?(coder: NSCoder) {
    fatalError()
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    window?.makeFirstResponder(self)
    addTrackingArea(
      NSTrackingArea(
        rect: bounds,
        options: [.mouseMoved, .activeAlways, .inVisibleRect],
        owner: self,
        userInfo: nil
      )
    )
  }

  override func draw(_ dirtyRect: NSRect) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }

    context.setFillColor(ReframedColors.overlayBackground.cgColor)
    context.fill(bounds)

    if let rect = selectionRect {
      context.setBlendMode(.clear)
      context.fill(rect)
      context.setBlendMode(.normal)

      context.setStrokeColor(ReframedColors.selectionBorder.cgColor)
      context.setLineWidth(1.0)
      context.setLineDash(phase: 0, lengths: [5, 4])
      context.stroke(rect)

      drawGrid(context: context, rect: rect)
      drawCircularHandles(context: context, rect: rect)
    } else {
      let crossColor = ReframedColors.crosshair
      context.setStrokeColor(crossColor.cgColor)
      context.setLineWidth(0.5)
      context.setLineDash(phase: 0, lengths: [])

      context.move(to: CGPoint(x: bounds.minX, y: mouseLocation.y))
      context.addLine(to: CGPoint(x: bounds.maxX, y: mouseLocation.y))
      context.strokePath()

      context.move(to: CGPoint(x: mouseLocation.x, y: bounds.minY))
      context.addLine(to: CGPoint(x: mouseLocation.x, y: bounds.maxY))
      context.strokePath()
    }
  }

  private func drawGrid(context: CGContext, rect: CGRect) {
    let gridColor = ReframedColors.selectionGrid
    context.setStrokeColor(gridColor.cgColor)
    context.setLineWidth(0.5)
    context.setLineDash(phase: 0, lengths: [4, 4])

    let thirdW = rect.width / 3
    for i in 1...2 {
      let x = rect.minX + thirdW * CGFloat(i)
      context.move(to: CGPoint(x: x, y: rect.minY))
      context.addLine(to: CGPoint(x: x, y: rect.maxY))
      context.strokePath()
    }

    let thirdH = rect.height / 3
    for i in 1...2 {
      let y = rect.minY + thirdH * CGFloat(i)
      context.move(to: CGPoint(x: rect.minX, y: y))
      context.addLine(to: CGPoint(x: rect.maxX, y: y))
      context.strokePath()
    }

    let centerColor = ReframedColors.selectionCenter
    context.setStrokeColor(centerColor.cgColor)
    context.setLineWidth(0.5)
    context.setLineDash(phase: 0, lengths: [6, 3])

    let cx = rect.midX
    let cy = rect.midY

    context.move(to: CGPoint(x: cx, y: rect.minY))
    context.addLine(to: CGPoint(x: cx, y: rect.maxY))
    context.strokePath()

    context.move(to: CGPoint(x: rect.minX, y: cy))
    context.addLine(to: CGPoint(x: rect.maxX, y: cy))
    context.strokePath()
  }

  private func drawCircularHandles(context: CGContext, rect: CGRect) {
    context.setLineDash(phase: 0, lengths: [])

    for handle in ResizeHandle.allCases {
      let handleRect = handle.rect(for: rect)
      let insetRect = handleRect.insetBy(dx: 1, dy: 1)

      context.setFillColor(ReframedColors.handleFill.cgColor)
      context.fillEllipse(in: insetRect)

      context.setStrokeColor(ReframedColors.handleStroke.cgColor)
      context.setLineWidth(1.5)
      context.strokeEllipse(in: insetRect)
    }
  }

  func applyExternalRect(_ newRect: CGRect) {
    selectionRect = newRect.clamped(to: bounds)
    needsDisplay = true
    updateControlsPanel()
  }

  func confirmSelection() {
    guard let rect = selectionRect, rect.width >= 10, rect.height >= 10 else {
      session.cancelSelection()
      return
    }

    guard let window = self.window else {
      session.cancelSelection()
      return
    }

    let windowRect = convert(rect, to: nil)
    let screenRect = window.convertToScreen(windowRect)
    let midPoint = CGPoint(x: screenRect.midX, y: screenRect.midY)
    let displayID = NSScreen.screens.first { $0.frame.contains(midPoint) }?.displayID ?? CGMainDisplayID()

    let selection = SelectionRect(rect: screenRect, displayID: displayID)
    session.confirmSelection(selection)
  }

  private func updateControlsPanel() {
    guard let rect = selectionRect else {
      controlsHost?.isHidden = true
      return
    }

    let isFirstCreate = controlsHost == nil
    if isFirstCreate {
      let view = CaptureAreaView(session: session)
      let hosting = NSHostingView(rootView: view)
      addSubview(hosting)
      controlsHost = hosting
    }

    guard let hosting = controlsHost else { return }

    if isFirstCreate {
      DispatchQueue.main.async {
        NotificationCenter.default.post(name: .selectionRectChanged, object: NSValue(rect: rect))
      }
    } else {
      NotificationCenter.default.post(name: .selectionRectChanged, object: NSValue(rect: rect))
    }

    let panelSize = hosting.intrinsicContentSize
    hosting.setFrameSize(panelSize)

    var panelX = rect.midX - panelSize.width / 2
    var panelY = rect.minY - panelSize.height - 16

    if panelY < bounds.minY + 8 {
      panelY = rect.maxY + 16
    }

    panelX = max(bounds.minX + 8, min(panelX, bounds.maxX - panelSize.width - 8))
    panelY = max(bounds.minY + 8, min(panelY, bounds.maxY - panelSize.height - 8))

    hosting.frame.origin = CGPoint(x: panelX, y: panelY)
    hosting.isHidden = false
  }

  override func mouseMoved(with event: NSEvent) {
    mouseLocation = convert(event.locationInWindow, from: nil)

    if let rect = selectionRect {
      var found = false
      for handle in ResizeHandle.allCases {
        let hitArea = handle.rect(for: rect).insetBy(dx: -4, dy: -4)
        if hitArea.contains(mouseLocation) {
          handle.cursor.set()
          found = true
          break
        }
      }
      if !found {
        if rect.contains(mouseLocation) {
          NSCursor.openHand.set()
        } else {
          NSCursor.arrow.set()
        }
      }
    } else {
      NSCursor.crosshair.set()
    }

    needsDisplay = true
  }

  override func mouseDown(with event: NSEvent) {
    session.overlayView = self
    let point = convert(event.locationInWindow, from: nil)

    if let hosting = controlsHost, !hosting.isHidden {
      let panelPoint = hosting.convert(point, from: self)
      if hosting.bounds.contains(panelPoint) {
        return
      }
    }

    if let rect = selectionRect {
      for handle in ResizeHandle.allCases {
        let hitArea = handle.rect(for: rect).insetBy(dx: -4, dy: -4)
        if hitArea.contains(point) {
          activeHandle = handle
          handleDragStart = point
          originalRectBeforeResize = rect
          return
        }
      }

      if rect.contains(point) {
        activeHandle = nil
        handleDragStart = point
        originalRectBeforeResize = rect
        NSCursor.closedHand.set()
        return
      }
    }

    dragOrigin = point
    selectionRect = nil
    isDragging = true
    controlsHost?.isHidden = true
    needsDisplay = true
  }

  override func mouseDragged(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)

    if let handle = activeHandle, let start = handleDragStart, let original = originalRectBeforeResize {
      let delta = CGPoint(x: point.x - start.x, y: point.y - start.y)
      selectionRect = handle.resize(original: original, delta: delta).normalized
      needsDisplay = true
      updateControlsPanel()
    } else if handleDragStart != nil, let original = originalRectBeforeResize {
      let delta = CGPoint(x: point.x - handleDragStart!.x, y: point.y - handleDragStart!.y)
      selectionRect = CGRect(
        x: original.origin.x + delta.x,
        y: original.origin.y + delta.y,
        width: original.width,
        height: original.height
      )
      needsDisplay = true
      updateControlsPanel()
    } else if let origin = dragOrigin {
      selectionRect = CGRect(
        x: min(origin.x, point.x),
        y: min(origin.y, point.y),
        width: abs(point.x - origin.x),
        height: abs(point.y - origin.y)
      )
      needsDisplay = true
      updateControlsPanel()
    }
  }

  override func mouseUp(with event: NSEvent) {
    if activeHandle != nil || handleDragStart != nil {
      activeHandle = nil
      handleDragStart = nil
      originalRectBeforeResize = nil
      updateControlsPanel()
      return
    }

    isDragging = false
    dragOrigin = nil

    if let rect = selectionRect, rect.width < 10 || rect.height < 10 {
      selectionRect = nil
      controlsHost?.isHidden = true
      needsDisplay = true
    } else if selectionRect != nil {
      updateControlsPanel()
    }
  }

  override func keyDown(with event: NSEvent) {
    if let responder = window?.firstResponder, responder is NSTextView {
      return
    }

    switch event.keyCode {
    case 53:
      session.cancelSelection()
    case 36:
      (session.overlayView ?? self).confirmSelection()
    default:
      super.keyDown(with: event)
    }
  }
}
