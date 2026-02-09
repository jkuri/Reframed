import AppKit

@MainActor
final class SelectionOverlayView: NSView {
  var onComplete: ((SelectionRect?) -> Void)?

  private var selectionRect: CGRect?
  private var dragOrigin: CGPoint?
  private var isDragging = false
  private var activeHandle: ResizeHandle?
  private var handleDragStart: CGPoint?
  private var originalRectBeforeResize: CGRect?
  private var mouseLocation: CGPoint = .zero

  // MARK: - Setup

  override var acceptsFirstResponder: Bool { true }
  override var isFlipped: Bool { false }

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

  // MARK: - Drawing

  override func draw(_ dirtyRect: NSRect) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }

    // Dimmed overlay
    context.setFillColor(NSColor.black.withAlphaComponent(0.3).cgColor)
    context.fill(bounds)

    if let rect = selectionRect {
      // Clear the selection area
      context.setBlendMode(.clear)
      context.fill(rect)
      context.setBlendMode(.normal)

      // Selection border
      let borderColor = NSColor.white.withAlphaComponent(0.8)
      context.setStrokeColor(borderColor.cgColor)
      context.setLineWidth(1.5)
      context.setLineDash(phase: 0, lengths: [6, 4])
      context.stroke(rect)

      // Resize handles
      context.setLineDash(phase: 0, lengths: [])
      for handle in ResizeHandle.allCases {
        let handleRect = handle.rect(for: rect)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(handleRect)
        context.setStrokeColor(NSColor.gray.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1)
        context.stroke(handleRect)
      }

      // Dimension label
      let w = Int(rect.width)
      let h = Int(rect.height)
      let label = "\(w) x \(h)"
      let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
        .foregroundColor: NSColor.white,
      ]
      let size = (label as NSString).size(withAttributes: attrs)
      let labelRect = CGRect(
        x: rect.midX - size.width / 2 - 6,
        y: rect.minY - size.height - 8,
        width: size.width + 12,
        height: size.height + 4
      )
      context.setFillColor(NSColor.black.withAlphaComponent(0.7).cgColor)
      let path = CGPath(roundedRect: labelRect, cornerWidth: 4, cornerHeight: 4, transform: nil)
      context.addPath(path)
      context.fillPath()
      (label as NSString).draw(
        at: CGPoint(x: labelRect.origin.x + 6, y: labelRect.origin.y + 2),
        withAttributes: attrs
      )
    } else {
      // Crosshair cursor lines
      let crossColor = NSColor.white.withAlphaComponent(0.5)
      context.setStrokeColor(crossColor.cgColor)
      context.setLineWidth(0.5)
      context.setLineDash(phase: 0, lengths: [])

      // Horizontal line
      context.move(to: CGPoint(x: bounds.minX, y: mouseLocation.y))
      context.addLine(to: CGPoint(x: bounds.maxX, y: mouseLocation.y))
      context.strokePath()

      // Vertical line
      context.move(to: CGPoint(x: mouseLocation.x, y: bounds.minY))
      context.addLine(to: CGPoint(x: mouseLocation.x, y: bounds.maxY))
      context.strokePath()
    }
  }

  // MARK: - Mouse Events

  override func mouseMoved(with event: NSEvent) {
    mouseLocation = convert(event.locationInWindow, from: nil)

    if let rect = selectionRect {
      var found = false
      for handle in ResizeHandle.allCases {
        let hitArea = handle.rect(for: rect).insetBy(dx: -4, dy: -4)
        if hitArea.contains(mouseLocation) {
          NSCursor.crosshair.set()
          found = true
          break
        }
      }
      if !found {
        if rect.contains(mouseLocation) {
          NSCursor.openHand.set()
        } else {
          NSCursor.crosshair.set()
        }
      }
    } else {
      NSCursor.crosshair.set()
    }

    needsDisplay = true
  }

  override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)

    // Check resize handles first
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

      // Check if clicking inside selection to move it
      if rect.contains(point) {
        activeHandle = nil
        handleDragStart = point
        originalRectBeforeResize = rect
        NSCursor.closedHand.set()
        return
      }
    }

    // Start new selection
    dragOrigin = point
    selectionRect = nil
    isDragging = true
    needsDisplay = true
  }

  override func mouseDragged(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)

    if let handle = activeHandle, let start = handleDragStart, let original = originalRectBeforeResize {
      // Resizing
      let delta = CGPoint(x: point.x - start.x, y: point.y - start.y)
      selectionRect = handle.resize(original: original, delta: delta).normalized
      needsDisplay = true
    } else if handleDragStart != nil, let original = originalRectBeforeResize {
      // Moving
      let delta = CGPoint(x: point.x - handleDragStart!.x, y: point.y - handleDragStart!.y)
      selectionRect = CGRect(
        x: original.origin.x + delta.x,
        y: original.origin.y + delta.y,
        width: original.width,
        height: original.height
      )
      needsDisplay = true
    } else if let origin = dragOrigin {
      // New selection
      selectionRect = CGRect(
        x: min(origin.x, point.x),
        y: min(origin.y, point.y),
        width: abs(point.x - origin.x),
        height: abs(point.y - origin.y)
      )
      needsDisplay = true
    }
  }

  override func mouseUp(with event: NSEvent) {
    if activeHandle != nil || handleDragStart != nil {
      activeHandle = nil
      handleDragStart = nil
      originalRectBeforeResize = nil
      return
    }

    isDragging = false
    dragOrigin = nil

    // If selection is too small, treat as click (clear)
    if let rect = selectionRect, rect.width < 10 || rect.height < 10 {
      selectionRect = nil
      needsDisplay = true
    }
  }

  override func keyDown(with event: NSEvent) {
    switch event.keyCode {
    case 53:  // ESC
      window?.orderOut(nil)
      onComplete?(nil)
    case 36:  // Enter
      confirmSelection()
    default:
      super.keyDown(with: event)
    }
  }

  // MARK: - Confirm

  private func confirmSelection() {
    guard let rect = selectionRect, rect.width >= 10, rect.height >= 10 else {
      onComplete?(nil)
      return
    }

    guard let window = self.window else {
      onComplete?(nil)
      return
    }

    // Convert view rect to screen coordinates
    let windowRect = convert(rect, to: nil)
    let screenRect = window.convertToScreen(windowRect)
    let displayID = NSScreen.displayID(for: CGPoint(x: screenRect.midX, y: screenRect.midY))

    let selection = SelectionRect(rect: screenRect, displayID: displayID)
    window.orderOut(nil)
    onComplete?(selection)
  }
}
