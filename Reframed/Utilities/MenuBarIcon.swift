import AppKit

enum MenuBarIcon {
  enum State {
    case idle
    case selecting
    case countdown
    case recording
    case paused
    case processing
    case processingPulse
    case editing
  }

  static var image: NSImage {
    makeImage(for: .idle)
  }

  static func makeImage(for state: State) -> NSImage {
    let size = NSSize(width: 18, height: 18)
    let img = NSImage(size: size, flipped: false) { rect in
      NSColor.black.setStroke()
      NSColor.black.setFill()
      drawBrackets(in: rect)
      drawCenter(for: state, in: rect)
      return true
    }
    img.isTemplate = true
    return img
  }

  private static func drawBrackets(in rect: NSRect) {
    let lineWidth: CGFloat = 1.8
    let inset: CGFloat = 1.8
    let cornerLen: CGFloat = 4.5
    let cornerRadius: CGFloat = 2.0
    let minX = inset
    let minY = inset
    let maxX = rect.width - inset
    let maxY = rect.height - inset

    let topLeft = NSBezierPath()
    topLeft.lineWidth = lineWidth
    topLeft.lineCapStyle = .round
    topLeft.lineJoinStyle = .round
    topLeft.move(to: NSPoint(x: minX, y: maxY - cornerLen))
    topLeft.line(to: NSPoint(x: minX, y: maxY - cornerRadius))
    topLeft.curve(
      to: NSPoint(x: minX + cornerRadius, y: maxY),
      controlPoint1: NSPoint(x: minX, y: maxY),
      controlPoint2: NSPoint(x: minX, y: maxY)
    )
    topLeft.line(to: NSPoint(x: minX + cornerLen, y: maxY))
    topLeft.stroke()

    let topRight = NSBezierPath()
    topRight.lineWidth = lineWidth
    topRight.lineCapStyle = .round
    topRight.lineJoinStyle = .round
    topRight.move(to: NSPoint(x: maxX - cornerLen, y: maxY))
    topRight.line(to: NSPoint(x: maxX - cornerRadius, y: maxY))
    topRight.curve(
      to: NSPoint(x: maxX, y: maxY - cornerRadius),
      controlPoint1: NSPoint(x: maxX, y: maxY),
      controlPoint2: NSPoint(x: maxX, y: maxY)
    )
    topRight.line(to: NSPoint(x: maxX, y: maxY - cornerLen))
    topRight.stroke()

    let bottomRight = NSBezierPath()
    bottomRight.lineWidth = lineWidth
    bottomRight.lineCapStyle = .round
    bottomRight.lineJoinStyle = .round
    bottomRight.move(to: NSPoint(x: maxX, y: minY + cornerLen))
    bottomRight.line(to: NSPoint(x: maxX, y: minY + cornerRadius))
    bottomRight.curve(
      to: NSPoint(x: maxX - cornerRadius, y: minY),
      controlPoint1: NSPoint(x: maxX, y: minY),
      controlPoint2: NSPoint(x: maxX, y: minY)
    )
    bottomRight.line(to: NSPoint(x: maxX - cornerLen, y: minY))
    bottomRight.stroke()

    let bottomLeft = NSBezierPath()
    bottomLeft.lineWidth = lineWidth
    bottomLeft.lineCapStyle = .round
    bottomLeft.lineJoinStyle = .round
    bottomLeft.move(to: NSPoint(x: minX + cornerLen, y: minY))
    bottomLeft.line(to: NSPoint(x: minX + cornerRadius, y: minY))
    bottomLeft.curve(
      to: NSPoint(x: minX, y: minY + cornerRadius),
      controlPoint1: NSPoint(x: minX, y: minY),
      controlPoint2: NSPoint(x: minX, y: minY)
    )
    bottomLeft.line(to: NSPoint(x: minX, y: minY + cornerLen))
    bottomLeft.stroke()
  }

  private static func drawCenter(for state: State, in rect: NSRect) {
    let cx = rect.midX
    let cy = rect.midY

    switch state {
    case .idle:
      break

    case .selecting:
      let crossSize: CGFloat = 2.5
      let path = NSBezierPath()
      path.lineWidth = 1.4
      path.lineCapStyle = .round
      path.move(to: NSPoint(x: cx - crossSize, y: cy))
      path.line(to: NSPoint(x: cx + crossSize, y: cy))
      path.move(to: NSPoint(x: cx, y: cy - crossSize))
      path.line(to: NSPoint(x: cx, y: cy + crossSize))
      path.stroke()

    case .countdown:
      NSColor.black.setFill()
      let dotRadius: CGFloat = 2.5
      let dot = NSBezierPath(
        ovalIn: NSRect(
          x: cx - dotRadius,
          y: cy - dotRadius,
          width: dotRadius * 2,
          height: dotRadius * 2
        )
      )
      dot.fill()

    case .recording:
      let circleRadius: CGFloat = 3.0
      let circle = NSBezierPath(
        ovalIn: NSRect(
          x: cx - circleRadius,
          y: cy - circleRadius,
          width: circleRadius * 2,
          height: circleRadius * 2
        )
      )
      circle.fill()

    case .paused:
      let barWidth: CGFloat = 1.6
      let barHeight: CGFloat = 5.0
      let gap: CGFloat = 1.6
      let leftBar = NSRect(
        x: cx - gap - barWidth,
        y: cy - barHeight / 2,
        width: barWidth,
        height: barHeight
      )
      let rightBar = NSRect(
        x: cx + gap,
        y: cy - barHeight / 2,
        width: barWidth,
        height: barHeight
      )
      NSBezierPath(roundedRect: leftBar, xRadius: 0.5, yRadius: 0.5).fill()
      NSBezierPath(roundedRect: rightBar, xRadius: 0.5, yRadius: 0.5).fill()

    case .processing:
      break

    case .processingPulse:
      NSColor.black.setFill()
      let dotRadius: CGFloat = 2.5
      let dot = NSBezierPath(
        ovalIn: NSRect(
          x: cx - dotRadius,
          y: cy - dotRadius,
          width: dotRadius * 2,
          height: dotRadius * 2
        )
      )
      dot.fill()

    case .editing:
      NSColor.black.setFill()
      let triW: CGFloat = 4.0
      let triH: CGFloat = 5.0
      let offsetX: CGFloat = 0.8
      let path = NSBezierPath()
      path.move(to: NSPoint(x: cx - triW / 2 + offsetX, y: cy + triH / 2))
      path.line(to: NSPoint(x: cx + triW / 2 + offsetX, y: cy))
      path.line(to: NSPoint(x: cx - triW / 2 + offsetX, y: cy - triH / 2))
      path.close()
      path.fill()
    }
  }
}
