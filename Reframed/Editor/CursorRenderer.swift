import CoreGraphics
import Foundation

enum CursorStyle: Int, Codable, Sendable, CaseIterable {
  case defaultArrow = 0
  case crosshair = 1
  case circleDot = 2

  var label: String {
    switch self {
    case .defaultArrow: "Arrow"
    case .crosshair: "Crosshair"
    case .circleDot: "Dot"
    }
  }
}

enum CursorRenderer {
  static func drawCursor(
    in context: CGContext,
    position: CGPoint,
    style: CursorStyle,
    size: CGFloat,
    scale: CGFloat = 1.0
  ) {
    let s = size * scale
    context.saveGState()

    switch style {
    case .defaultArrow:
      drawArrowCursor(in: context, at: position, size: s)
    case .crosshair:
      drawCrosshairCursor(in: context, at: position, size: s)
    case .circleDot:
      drawCircleDotCursor(in: context, at: position, size: s)
    }

    context.restoreGState()
  }

  static func drawClickHighlight(
    in context: CGContext,
    position: CGPoint,
    progress: Double,
    size: CGFloat,
    scale: CGFloat = 1.0,
    color: CGColor? = nil
  ) {
    let baseSize = size * scale
    let startDiameter = baseSize * 0.5
    let endDiameter = baseSize * 2.0
    let currentDiameter = startDiameter + (endDiameter - startDiameter) * CGFloat(progress)
    let opacity = CGFloat(1.0 - progress)

    let radius = currentDiameter / 2
    let circleRect = CGRect(
      x: position.x - radius,
      y: position.y - radius,
      width: currentDiameter,
      height: currentDiameter
    )

    let components = color?.components ?? [0.2, 0.5, 1.0, 1.0]
    let r = components.count > 0 ? components[0] : 0.2
    let g = components.count > 1 ? components[1] : 0.5
    let b = components.count > 2 ? components[2] : 1.0

    context.saveGState()
    context.setFillColor(CGColor(srgbRed: r, green: g, blue: b, alpha: 0.25 * opacity))
    context.fillEllipse(in: circleRect)
    context.setStrokeColor(CGColor(srgbRed: r, green: g, blue: b, alpha: 0.7 * opacity))
    context.setLineWidth(2.0 * scale)
    context.strokeEllipse(in: circleRect)
    context.restoreGState()
  }

  private static func drawArrowCursor(in context: CGContext, at point: CGPoint, size: CGFloat) {
    let s = size / 24.0
    let x = point.x
    let y = point.y

    let path = CGMutablePath()
    path.move(to: CGPoint(x: x, y: y))
    path.addLine(to: CGPoint(x: x, y: y + 20 * s))
    path.addLine(to: CGPoint(x: x + 5.5 * s, y: y + 15.5 * s))
    path.addLine(to: CGPoint(x: x + 9 * s, y: y + 22 * s))
    path.addLine(to: CGPoint(x: x + 12 * s, y: y + 20.5 * s))
    path.addLine(to: CGPoint(x: x + 8.5 * s, y: y + 13.5 * s))
    path.addLine(to: CGPoint(x: x + 15 * s, y: y + 13.5 * s))
    path.closeSubpath()

    context.addPath(path)
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.fillPath()

    context.addPath(path)
    context.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.8))
    context.setLineWidth(1.5 * (size / 24.0))
    context.strokePath()
  }

  private static func drawCrosshairCursor(in context: CGContext, at point: CGPoint, size: CGFloat) {
    let halfLen = size / 2
    let gap = size * 0.15
    let lineWidth = max(1.5, size / 16)

    context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.setLineWidth(lineWidth + 1)

    let lines: [(CGPoint, CGPoint)] = [
      (CGPoint(x: point.x - halfLen, y: point.y), CGPoint(x: point.x - gap, y: point.y)),
      (CGPoint(x: point.x + gap, y: point.y), CGPoint(x: point.x + halfLen, y: point.y)),
      (CGPoint(x: point.x, y: point.y - halfLen), CGPoint(x: point.x, y: point.y - gap)),
      (CGPoint(x: point.x, y: point.y + gap), CGPoint(x: point.x, y: point.y + halfLen)),
    ]

    for (start, end) in lines {
      context.move(to: start)
      context.addLine(to: end)
    }
    context.strokePath()

    context.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.9))
    context.setLineWidth(lineWidth)
    for (start, end) in lines {
      context.move(to: start)
      context.addLine(to: end)
    }
    context.strokePath()
  }

  private static func drawCircleDotCursor(in context: CGContext, at point: CGPoint, size: CGFloat) {
    let outerRadius = size / 2
    let innerRadius = size * 0.15
    let lineWidth = max(1.5, size / 12)

    let outerRect = CGRect(
      x: point.x - outerRadius,
      y: point.y - outerRadius,
      width: outerRadius * 2,
      height: outerRadius * 2
    )

    context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.9))
    context.setLineWidth(lineWidth + 1)
    context.strokeEllipse(in: outerRect)

    context.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.7))
    context.setLineWidth(lineWidth)
    context.strokeEllipse(in: outerRect)

    let innerRect = CGRect(
      x: point.x - innerRadius,
      y: point.y - innerRadius,
      width: innerRadius * 2,
      height: innerRadius * 2
    )
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.fillEllipse(in: innerRect)
  }
}
