import AppKit
import CoreGraphics
import Foundation

enum CursorStyle: Int, Codable, Sendable, CaseIterable {
  case defaultArrow = 0
  case crosshair = 1
  case circleDot = 2
  case outlineArrow = 3
  case dot = 4
  case circle = 5
  case bullseye = 6
  case diamond = 7
  case plus = 8
  case spotlight = 9
  case crosshairDot = 10
  case invertedArrow = 11
  case pointer = 12
  case grab = 13
  case pencil = 14
  case pen = 15
  case blueArrow = 16
  case goldPointer = 17
  case target = 18
  case marker = 19

  var label: String {
    switch self {
    case .defaultArrow: "Arrow"
    case .crosshair: "Crosshair"
    case .circleDot: "Ring Dot"
    case .outlineArrow: "Outline"
    case .dot: "Dot"
    case .circle: "Circle"
    case .bullseye: "Bullseye"
    case .diamond: "Diamond"
    case .plus: "Plus"
    case .spotlight: "Spotlight"
    case .crosshairDot: "Cross Dot"
    case .invertedArrow: "Inverted"
    case .pointer: "Pointer"
    case .grab: "Grab"
    case .pencil: "Pencil"
    case .pen: "Pen"
    case .blueArrow: "Blue Arrow"
    case .goldPointer: "Gold Hand"
    case .target: "Target"
    case .marker: "Marker"
    }
  }

  var isCentered: Bool {
    switch self {
    case .defaultArrow, .outlineArrow, .invertedArrow,
      .pointer, .pencil, .pen, .blueArrow, .goldPointer, .marker:
      false
    default: true
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
    case .outlineArrow:
      drawOutlineArrowCursor(in: context, at: position, size: s)
    case .dot:
      drawDotCursor(in: context, at: position, size: s)
    case .circle:
      drawCircleCursor(in: context, at: position, size: s)
    case .bullseye:
      drawBullseyeCursor(in: context, at: position, size: s)
    case .diamond:
      drawDiamondCursor(in: context, at: position, size: s)
    case .plus:
      drawPlusCursor(in: context, at: position, size: s)
    case .spotlight:
      drawSpotlightCursor(in: context, at: position, size: s)
    case .crosshairDot:
      drawCrosshairDotCursor(in: context, at: position, size: s)
    case .invertedArrow:
      drawInvertedArrowCursor(in: context, at: position, size: s)
    case .pointer:
      drawPointerCursor(in: context, at: position, size: s)
    case .grab:
      drawGrabCursor(in: context, at: position, size: s)
    case .pencil:
      drawPencilCursor(in: context, at: position, size: s)
    case .pen:
      drawPenCursor(in: context, at: position, size: s)
    case .blueArrow:
      drawBlueArrowCursor(in: context, at: position, size: s)
    case .goldPointer:
      drawGoldPointerCursor(in: context, at: position, size: s)
    case .target:
      drawTargetCursor(in: context, at: position, size: s)
    case .marker:
      drawMarkerCursor(in: context, at: position, size: s)
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

  // MARK: - Arrow variants

  private static func arrowPath(at point: CGPoint, scale s: CGFloat) -> CGMutablePath {
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
    return path
  }

  private static func drawArrowCursor(in context: CGContext, at point: CGPoint, size: CGFloat) {
    let s = size / 24.0
    let path = arrowPath(at: point, scale: s)

    context.addPath(path)
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.fillPath()

    context.addPath(path)
    context.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.8))
    context.setLineWidth(1.5 * s)
    context.strokePath()
  }

  private static func drawOutlineArrowCursor(in context: CGContext, at point: CGPoint, size: CGFloat) {
    let s = size / 24.0
    let path = arrowPath(at: point, scale: s)

    context.addPath(path)
    context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.setLineWidth(2.5 * s)
    context.strokePath()

    context.addPath(path)
    context.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.6))
    context.setLineWidth(1.2 * s)
    context.strokePath()
  }

  private static func drawInvertedArrowCursor(in context: CGContext, at point: CGPoint, size: CGFloat) {
    let s = size / 24.0
    let path = arrowPath(at: point, scale: s)

    context.addPath(path)
    context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.9))
    context.fillPath()

    context.addPath(path)
    context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.setLineWidth(1.5 * s)
    context.strokePath()
  }

  private static func drawBlueArrowCursor(in context: CGContext, at point: CGPoint, size: CGFloat) {
    let s = size / 24.0
    let path = arrowPath(at: point, scale: s)

    context.addPath(path)
    context.setFillColor(CGColor(srgbRed: 0.23, green: 0.51, blue: 0.96, alpha: 1))
    context.fillPath()

    context.addPath(path)
    context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.9))
    context.setLineWidth(1.5 * s)
    context.strokePath()
  }

  // MARK: - Hand variants

  private static func pointerPath(at point: CGPoint, scale s: CGFloat) -> CGMutablePath {
    let x = point.x
    let y = point.y
    let path = CGMutablePath()
    path.move(to: CGPoint(x: x + 1.5 * s, y: y))
    path.addLine(to: CGPoint(x: x + 4 * s, y: y + 2.5 * s))
    path.addLine(to: CGPoint(x: x + 4 * s, y: y + 11 * s))
    path.addLine(to: CGPoint(x: x + 7 * s, y: y + 10 * s))
    path.addLine(to: CGPoint(x: x + 7.5 * s, y: y + 12.5 * s))
    path.addLine(to: CGPoint(x: x + 10 * s, y: y + 11.5 * s))
    path.addLine(to: CGPoint(x: x + 10.5 * s, y: y + 14 * s))
    path.addLine(to: CGPoint(x: x + 13 * s, y: y + 13 * s))
    path.addLine(to: CGPoint(x: x + 13 * s, y: y + 18 * s))
    path.addLine(to: CGPoint(x: x + 10 * s, y: y + 22 * s))
    path.addLine(to: CGPoint(x: x - 1 * s, y: y + 22 * s))
    path.addLine(to: CGPoint(x: x - 1 * s, y: y + 2.5 * s))
    path.closeSubpath()
    return path
  }

  private static func drawPointerCursor(in context: CGContext, at point: CGPoint, size: CGFloat) {
    let s = size / 24.0
    let path = pointerPath(at: point, scale: s)

    context.addPath(path)
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.fillPath()

    context.addPath(path)
    context.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.8))
    context.setLineWidth(1.2 * s)
    context.strokePath()
  }

  private static func drawGoldPointerCursor(in context: CGContext, at point: CGPoint, size: CGFloat) {
    let s = size / 24.0
    let path = pointerPath(at: point, scale: s)

    context.addPath(path)
    context.setFillColor(CGColor(srgbRed: 1.0, green: 0.82, blue: 0.2, alpha: 1))
    context.fillPath()

    context.addPath(path)
    context.setStrokeColor(CGColor(srgbRed: 0.5, green: 0.4, blue: 0.0, alpha: 0.8))
    context.setLineWidth(1.2 * s)
    context.strokePath()
  }

  private static func drawGrabCursor(in context: CGContext, at point: CGPoint, size: CGFloat) {
    let s = size / 24.0
    let x = point.x
    let y = point.y

    let path = CGMutablePath()
    path.move(to: CGPoint(x: x - 5 * s, y: y + 8 * s))
    path.addLine(to: CGPoint(x: x - 6 * s, y: y + 2 * s))
    path.addLine(to: CGPoint(x: x - 9 * s, y: y - 1.5 * s))
    path.addLine(to: CGPoint(x: x - 7.5 * s, y: y - 3 * s))
    path.addLine(to: CGPoint(x: x - 5 * s, y: y + 0.5 * s))
    path.addLine(to: CGPoint(x: x - 4.5 * s, y: y - 7 * s))
    path.addLine(to: CGPoint(x: x - 2.5 * s, y: y - 7.5 * s))
    path.addLine(to: CGPoint(x: x - 2 * s, y: y - 0.5 * s))
    path.addLine(to: CGPoint(x: x - 1 * s, y: y - 9 * s))
    path.addLine(to: CGPoint(x: x + 1 * s, y: y - 9.5 * s))
    path.addLine(to: CGPoint(x: x + 1.5 * s, y: y - 0.5 * s))
    path.addLine(to: CGPoint(x: x + 2.5 * s, y: y - 7 * s))
    path.addLine(to: CGPoint(x: x + 4.5 * s, y: y - 7 * s))
    path.addLine(to: CGPoint(x: x + 4.5 * s, y: y + 0.5 * s))
    path.addLine(to: CGPoint(x: x + 5.5 * s, y: y - 5 * s))
    path.addLine(to: CGPoint(x: x + 7.5 * s, y: y - 4.5 * s))
    path.addLine(to: CGPoint(x: x + 7.5 * s, y: y + 3 * s))
    path.addLine(to: CGPoint(x: x + 6 * s, y: y + 8 * s))
    path.closeSubpath()

    context.addPath(path)
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.fillPath()

    context.addPath(path)
    context.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.8))
    context.setLineWidth(1.2 * s)
    context.strokePath()
  }

  // MARK: - Crosshair variants

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

  private static func drawCrosshairDotCursor(in context: CGContext, at point: CGPoint, size: CGFloat) {
    let halfLen = size / 2
    let gap = size * 0.2
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

    let dotRadius = size * 0.08
    let dotRect = CGRect(
      x: point.x - dotRadius,
      y: point.y - dotRadius,
      width: dotRadius * 2,
      height: dotRadius * 2
    )
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.fillEllipse(in: dotRect)
  }

  private static func drawTargetCursor(in context: CGContext, at point: CGPoint, size: CGFloat) {
    let radius = size / 2
    let lineWidth = max(1.5, size / 14)
    let gap = size * 0.1

    let circleRect = CGRect(
      x: point.x - radius,
      y: point.y - radius,
      width: radius * 2,
      height: radius * 2
    )

    let lines: [(CGPoint, CGPoint)] = [
      (CGPoint(x: point.x - radius, y: point.y), CGPoint(x: point.x - gap, y: point.y)),
      (CGPoint(x: point.x + gap, y: point.y), CGPoint(x: point.x + radius, y: point.y)),
      (CGPoint(x: point.x, y: point.y - radius), CGPoint(x: point.x, y: point.y - gap)),
      (CGPoint(x: point.x, y: point.y + gap), CGPoint(x: point.x, y: point.y + radius)),
    ]

    context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.95))
    context.setLineWidth(lineWidth + 1)
    context.strokeEllipse(in: circleRect)
    for (start, end) in lines {
      context.move(to: start)
      context.addLine(to: end)
    }
    context.strokePath()

    context.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.7))
    context.setLineWidth(lineWidth)
    context.strokeEllipse(in: circleRect)
    for (start, end) in lines {
      context.move(to: start)
      context.addLine(to: end)
    }
    context.strokePath()

    let dotR = size * 0.06
    let dotRect = CGRect(
      x: point.x - dotR,
      y: point.y - dotR,
      width: dotR * 2,
      height: dotR * 2
    )
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.fillEllipse(in: dotRect)
  }

  // MARK: - Circle variants

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

  private static func drawDotCursor(in context: CGContext, at point: CGPoint, size: CGFloat) {
    let radius = size * 0.35
    let dotRect = CGRect(
      x: point.x - radius,
      y: point.y - radius,
      width: radius * 2,
      height: radius * 2
    )

    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.fillEllipse(in: dotRect)
    context.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.6))
    context.setLineWidth(max(1.0, size / 16))
    context.strokeEllipse(in: dotRect)
  }

  private static func drawCircleCursor(in context: CGContext, at point: CGPoint, size: CGFloat) {
    let radius = size / 2
    let lineWidth = max(1.5, size / 10)
    let circleRect = CGRect(
      x: point.x - radius,
      y: point.y - radius,
      width: radius * 2,
      height: radius * 2
    )

    context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.95))
    context.setLineWidth(lineWidth + 1)
    context.strokeEllipse(in: circleRect)

    context.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.7))
    context.setLineWidth(lineWidth)
    context.strokeEllipse(in: circleRect)
  }

  private static func drawBullseyeCursor(in context: CGContext, at point: CGPoint, size: CGFloat) {
    let outerRadius = size / 2
    let midRadius = size * 0.3
    let innerRadius = size * 0.12
    let lineWidth = max(1.0, size / 16)

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

    let midRect = CGRect(
      x: point.x - midRadius,
      y: point.y - midRadius,
      width: midRadius * 2,
      height: midRadius * 2
    )
    context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.9))
    context.setLineWidth(lineWidth + 1)
    context.strokeEllipse(in: midRect)
    context.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.7))
    context.setLineWidth(lineWidth)
    context.strokeEllipse(in: midRect)

    let innerRect = CGRect(
      x: point.x - innerRadius,
      y: point.y - innerRadius,
      width: innerRadius * 2,
      height: innerRadius * 2
    )
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.fillEllipse(in: innerRect)
  }

  private static func drawSpotlightCursor(in context: CGContext, at point: CGPoint, size: CGFloat) {
    let radius = size / 2
    let circleRect = CGRect(
      x: point.x - radius,
      y: point.y - radius,
      width: radius * 2,
      height: radius * 2
    )

    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.3))
    context.fillEllipse(in: circleRect)

    context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.9))
    context.setLineWidth(max(1.5, size / 12))
    context.strokeEllipse(in: circleRect)
  }

  // MARK: - Geometric shapes

  private static func drawDiamondCursor(in context: CGContext, at point: CGPoint, size: CGFloat) {
    let half = size / 2
    let lineWidth = max(1.5, size / 14)

    let path = CGMutablePath()
    path.move(to: CGPoint(x: point.x, y: point.y - half))
    path.addLine(to: CGPoint(x: point.x + half, y: point.y))
    path.addLine(to: CGPoint(x: point.x, y: point.y + half))
    path.addLine(to: CGPoint(x: point.x - half, y: point.y))
    path.closeSubpath()

    context.addPath(path)
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.15))
    context.fillPath()

    context.addPath(path)
    context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.setLineWidth(lineWidth + 1)
    context.strokePath()

    context.addPath(path)
    context.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.7))
    context.setLineWidth(lineWidth)
    context.strokePath()
  }

  private static func drawPlusCursor(in context: CGContext, at point: CGPoint, size: CGFloat) {
    let halfLen = size / 2
    let thickness = max(2.0, size / 6)

    let hRect = CGRect(
      x: point.x - halfLen,
      y: point.y - thickness / 2,
      width: size,
      height: thickness
    )
    let vRect = CGRect(
      x: point.x - thickness / 2,
      y: point.y - halfLen,
      width: thickness,
      height: size
    )

    let plusPath = CGMutablePath()
    plusPath.addRect(hRect)
    plusPath.addRect(vRect)

    context.addPath(plusPath)
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.fillPath()

    context.addPath(plusPath)
    context.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.6))
    context.setLineWidth(max(1.0, size / 20))
    context.strokePath()
  }

  // MARK: - Writing instruments

  private static func drawPencilCursor(in context: CGContext, at point: CGPoint, size: CGFloat) {
    let s = size / 24.0
    let x = point.x
    let y = point.y
    let c: CGFloat = 0.707

    let outline = CGMutablePath()
    outline.move(to: CGPoint(x: x, y: y))
    outline.addLine(to: CGPoint(x: x + 6 * c * s, y: y + 2 * c * s))
    outline.addLine(to: CGPoint(x: x + 20 * c * s, y: y + 16 * c * s))
    outline.addLine(to: CGPoint(x: x + 23 * c * s, y: y + 19 * c * s))
    outline.addLine(to: CGPoint(x: x + 19 * c * s, y: y + 23 * c * s))
    outline.addLine(to: CGPoint(x: x + 16 * c * s, y: y + 20 * c * s))
    outline.addLine(to: CGPoint(x: x + 2 * c * s, y: y + 6 * c * s))
    outline.closeSubpath()

    context.addPath(outline)
    context.setFillColor(CGColor(srgbRed: 1, green: 0.84, blue: 0.25, alpha: 1))
    context.fillPath()

    let tipPath = CGMutablePath()
    tipPath.move(to: CGPoint(x: x, y: y))
    tipPath.addLine(to: CGPoint(x: x + 6 * c * s, y: y + 2 * c * s))
    tipPath.addLine(to: CGPoint(x: x + 2 * c * s, y: y + 6 * c * s))
    tipPath.closeSubpath()
    context.addPath(tipPath)
    context.setFillColor(CGColor(srgbRed: 0.35, green: 0.35, blue: 0.35, alpha: 1))
    context.fillPath()

    let eraserPath = CGMutablePath()
    eraserPath.move(to: CGPoint(x: x + 20 * c * s, y: y + 16 * c * s))
    eraserPath.addLine(to: CGPoint(x: x + 23 * c * s, y: y + 19 * c * s))
    eraserPath.addLine(to: CGPoint(x: x + 19 * c * s, y: y + 23 * c * s))
    eraserPath.addLine(to: CGPoint(x: x + 16 * c * s, y: y + 20 * c * s))
    eraserPath.closeSubpath()
    context.addPath(eraserPath)
    context.setFillColor(CGColor(srgbRed: 0.95, green: 0.55, blue: 0.55, alpha: 1))
    context.fillPath()

    context.addPath(outline)
    context.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.7))
    context.setLineWidth(1.0 * s)
    context.strokePath()
  }

  private static func drawPenCursor(in context: CGContext, at point: CGPoint, size: CGFloat) {
    let s = size / 24.0
    let x = point.x
    let y = point.y
    let c: CGFloat = 0.707

    let outline = CGMutablePath()
    outline.move(to: CGPoint(x: x, y: y))
    outline.addLine(to: CGPoint(x: x + 6.5 * c * s, y: y + 3.5 * c * s))
    outline.addLine(to: CGPoint(x: x + 21.5 * c * s, y: y + 18.5 * c * s))
    outline.addLine(to: CGPoint(x: x + 18.5 * c * s, y: y + 21.5 * c * s))
    outline.addLine(to: CGPoint(x: x + 3.5 * c * s, y: y + 6.5 * c * s))
    outline.closeSubpath()

    context.addPath(outline)
    context.setFillColor(CGColor(srgbRed: 0.2, green: 0.2, blue: 0.35, alpha: 1))
    context.fillPath()

    let nibPath = CGMutablePath()
    nibPath.move(to: CGPoint(x: x, y: y))
    nibPath.addLine(to: CGPoint(x: x + 6.5 * c * s, y: y + 3.5 * c * s))
    nibPath.addLine(to: CGPoint(x: x + 3.5 * c * s, y: y + 6.5 * c * s))
    nibPath.closeSubpath()
    context.addPath(nibPath)
    context.setFillColor(CGColor(srgbRed: 0.7, green: 0.7, blue: 0.75, alpha: 1))
    context.fillPath()

    context.addPath(outline)
    context.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.7))
    context.setLineWidth(1.0 * s)
    context.strokePath()
  }

  private static func drawMarkerCursor(in context: CGContext, at point: CGPoint, size: CGFloat) {
    let s = size / 24.0
    let x = point.x
    let y = point.y
    let c: CGFloat = 0.707

    let tw: CGFloat = 5
    let bl: CGFloat = 15
    let capL: CGFloat = 3

    let outline = CGMutablePath()
    outline.move(to: CGPoint(x: x, y: y))
    outline.addLine(to: CGPoint(x: x + tw * c * s, y: y - tw * c * s))
    outline.addLine(to: CGPoint(x: x + (tw + bl) * c * s, y: y + (bl - tw) * c * s))
    outline.addLine(to: CGPoint(x: x + (tw + bl + capL) * c * s, y: y + (bl + capL - tw) * c * s))
    outline.addLine(to: CGPoint(x: x + (bl + capL) * c * s, y: y + (bl + capL) * c * s))
    outline.addLine(to: CGPoint(x: x + bl * c * s, y: y + bl * c * s))
    outline.closeSubpath()

    context.addPath(outline)
    context.setFillColor(CGColor(srgbRed: 0.18, green: 0.8, blue: 0.44, alpha: 1))
    context.fillPath()

    let capPath = CGMutablePath()
    capPath.move(to: CGPoint(x: x + (tw + bl) * c * s, y: y + (bl - tw) * c * s))
    capPath.addLine(to: CGPoint(x: x + (tw + bl + capL) * c * s, y: y + (bl + capL - tw) * c * s))
    capPath.addLine(to: CGPoint(x: x + (bl + capL) * c * s, y: y + (bl + capL) * c * s))
    capPath.addLine(to: CGPoint(x: x + bl * c * s, y: y + bl * c * s))
    capPath.closeSubpath()
    context.addPath(capPath)
    context.setFillColor(CGColor(srgbRed: 0.12, green: 0.55, blue: 0.30, alpha: 1))
    context.fillPath()

    context.addPath(outline)
    context.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.7))
    context.setLineWidth(1.0 * s)
    context.strokePath()
  }

  // MARK: - Preview

  @MainActor static func previewImage(for style: CursorStyle, size: CGFloat) -> NSImage {
    let scale = NSScreen.main?.backingScaleFactor ?? 2.0
    let imgSize = size
    let pixelW = Int(imgSize * scale)
    let pixelH = Int(imgSize * scale)

    let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
    guard
      let ctx = CGContext(
        data: nil,
        width: pixelW,
        height: pixelH,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: bitmapInfo
      )
    else {
      return NSImage(size: NSSize(width: imgSize, height: imgSize))
    }

    ctx.clear(CGRect(x: 0, y: 0, width: pixelW, height: pixelH))
    ctx.translateBy(x: 0, y: CGFloat(pixelH))
    ctx.scaleBy(x: 1, y: -1)

    let cursorDrawSize = imgSize * scale * 0.55
    let drawPoint: CGPoint
    if style.isCentered {
      drawPoint = CGPoint(x: CGFloat(pixelW) / 2, y: CGFloat(pixelH) / 2)
    } else {
      let offsetX = CGFloat(pixelW) * 0.22
      let offsetY = CGFloat(pixelH) * 0.12
      drawPoint = CGPoint(x: offsetX, y: offsetY)
    }

    drawCursor(in: ctx, position: drawPoint, style: style, size: cursorDrawSize, scale: 1.0)

    guard let cgImage = ctx.makeImage() else {
      return NSImage(size: NSSize(width: imgSize, height: imgSize))
    }

    return NSImage(cgImage: cgImage, size: NSSize(width: imgSize, height: imgSize))
  }
}
