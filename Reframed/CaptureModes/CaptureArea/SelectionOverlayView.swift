import AppKit
import SwiftUI

@MainActor
final class SelectionOverlayView: NSView {
  let session: SessionState

  var selectionRect: CGRect?
  var dragOrigin: CGPoint?
  var isDragging = false
  var activeHandle: ResizeHandle?
  var handleDragStart: CGPoint?
  var originalRectBeforeResize: CGRect?
  var mouseLocation: CGPoint = .zero
  var controlsHost: NSHostingView<CaptureAreaView>?

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
    let shiftHeld = event.modifierFlags.contains(.shift)

    if let handle = activeHandle, let start = handleDragStart, let original = originalRectBeforeResize {
      let delta = CGPoint(x: point.x - start.x, y: point.y - start.y)
      var newRect = handle.resize(original: original, delta: delta).normalized
      if shiftHeld, original.width > 0, original.height > 0 {
        let aspect = original.width / original.height
        newRect = constrainToAspect(original, delta: delta, aspect: aspect, handle: handle)
      }
      selectionRect = newRect
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
      let w = abs(point.x - origin.x)
      var h = abs(point.y - origin.y)
      if shiftHeld, w > 0, h > 0 {
        h = w * 9.0 / 16.0
      }
      selectionRect = CGRect(
        x: point.x >= origin.x ? origin.x : origin.x - w,
        y: point.y >= origin.y ? origin.y : origin.y - h,
        width: w,
        height: h
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
    case 53:  // escape
      session.cancelSelection()
    case 36:  // enter
      NotificationCenter.default.post(name: .areaSelectionConfirmRequested, object: nil)
    default:
      super.keyDown(with: event)
    }
  }
}
