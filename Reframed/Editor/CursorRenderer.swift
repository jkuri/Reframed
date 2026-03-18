import AppKit
import CoreGraphics
import Foundation

enum CursorStyle: Int, Codable, Sendable, CaseIterable {
  case centerDefault = 0
  case centerSecondary = 1
  case centerPointer = 2
  case centerFoff = 3
  case centerDot = 4
  case centerCircle = 5
  case centerRingDot = 6
  case centerBullseye = 7
  case centerDiamond = 8
  case centerPlus = 9
  case centerCrosshair = 10
  case centerCrossDot = 11
  case centerCrossGap = 12
  case centerSpotlight = 13
  case centerBrackets = 14
  case centerCorners = 15
  case centerSquare = 16
  case centerStar = 17
  case centerTriangle = 18
  case centerX = 19
  case cursorPen = 20
  case cursorMarker = 21

  var label: String {
    switch self {
    case .centerDefault: "Default"
    case .centerSecondary: "Secondary"
    case .centerPointer: "Pointer"
    case .centerFoff: "Foff"
    case .centerDot: "Dot"
    case .centerCircle: "Circle"
    case .centerRingDot: "Ring Dot"
    case .centerBullseye: "Bullseye"
    case .centerDiamond: "Diamond"
    case .centerPlus: "Plus"
    case .centerCrosshair: "Crosshair"
    case .centerCrossDot: "Cross Dot"
    case .centerCrossGap: "Cross Gap"
    case .centerSpotlight: "Spotlight"
    case .centerBrackets: "Brackets"
    case .centerCorners: "Corners"
    case .centerSquare: "Square"
    case .centerStar: "Star"
    case .centerTriangle: "Triangle"
    case .centerX: "X"
    case .cursorPen: "Pen"
    case .cursorMarker: "Marker"
    }
  }

  var isCentered: Bool {
    switch self {
    case .cursorPen, .cursorMarker:
      false
    default: true
    }
  }
}

enum CursorRenderer {
  static func colorizedSVG(for style: CursorStyle, fillHex: String, strokeHex: String) -> String {
    style.svgTemplate
      .replacingOccurrences(of: "#000", with: strokeHex)
      .replacingOccurrences(of: "currentColor", with: fillHex)
  }

  static func renderSVGToImage(svgString: String, pixelSize: Int) -> CGImage? {
    guard pixelSize > 0,
      let data = svgString.data(using: .utf8),
      let nsImage = NSImage(data: data)
    else { return nil }
    let bitmapInfo =
      CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
    guard
      let ctx = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: bitmapInfo
      )
    else { return nil }
    ctx.clear(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    ctx.translateBy(x: 0, y: CGFloat(pixelSize))
    ctx.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    nsImage.draw(
      in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
      from: .zero,
      operation: .sourceOver,
      fraction: 1.0
    )
    NSGraphicsContext.restoreGraphicsState()
    return ctx.makeImage()
  }

  static func drawCursor(
    in context: CGContext,
    position: CGPoint,
    style: CursorStyle,
    size: CGFloat,
    scale: CGFloat = 1.0,
    fillColor: CodableColor = CodableColor(r: 1, g: 1, b: 1),
    strokeColor: CodableColor = CodableColor(r: 0, g: 0, b: 0),
    rotation: CGFloat = 0,
    bounceScale: CGFloat = 1.0,
    motionBlurDx: CGFloat = 0,
    motionBlurDy: CGFloat = 0,
    motionBlurMagnitude: CGFloat = 0
  ) {
    let s = size * scale * bounceScale
    let pixelSize = Int(ceil(size * scale))
    let svg = colorizedSVG(for: style, fillHex: fillColor.hexString, strokeHex: strokeColor.hexString)
    guard let image = renderSVGToImage(svgString: svg, pixelSize: pixelSize) else { return }

    if motionBlurMagnitude > 1.0 {
      let samples = min(Int(motionBlurMagnitude / 3) + 3, CursorEffects.motionBlurMaxSamples)
      let maxOffset = min(motionBlurMagnitude, CursorEffects.motionBlurMaxOffset)
      let dirX = motionBlurDx / motionBlurMagnitude
      let dirY = motionBlurDy / motionBlurMagnitude
      for i in (1..<samples).reversed() {
        let fraction = CGFloat(i) / CGFloat(samples)
        let offset = maxOffset * fraction
        let alpha = (1.0 - fraction) * 0.5
        let offsetPos = CGPoint(
          x: position.x - dirX * offset,
          y: position.y - dirY * offset
        )
        drawSingleCursor(
          in: context,
          image: image,
          position: offsetPos,
          size: s,
          style: style,
          rotation: rotation,
          alpha: alpha
        )
      }
    }

    drawSingleCursor(
      in: context,
      image: image,
      position: position,
      size: s,
      style: style,
      rotation: rotation,
      alpha: 1.0
    )
  }

  private static func drawSingleCursor(
    in context: CGContext,
    image: CGImage,
    position: CGPoint,
    size: CGFloat,
    style: CursorStyle,
    rotation: CGFloat,
    alpha: CGFloat
  ) {
    context.saveGState()
    if alpha < 1.0 {
      context.setAlpha(alpha)
    }
    let drawRect: CGRect
    if style.isCentered {
      drawRect = CGRect(x: -size / 2, y: -size / 2, width: size, height: size)
    } else {
      drawRect = CGRect(x: 0, y: 0, width: size, height: size)
    }
    context.translateBy(x: position.x, y: position.y)
    if abs(rotation) > 0.001 {
      context.rotate(by: rotation)
    }
    context.draw(image, in: drawRect)
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

  @MainActor static func previewImage(
    for style: CursorStyle,
    size: CGFloat,
    fillColor: CodableColor = CodableColor(r: 1, g: 1, b: 1),
    strokeColor: CodableColor = CodableColor(r: 0, g: 0, b: 0)
  ) -> NSImage {
    let svg = colorizedSVG(for: style, fillHex: fillColor.hexString, strokeHex: strokeColor.hexString)
    guard let data = svg.data(using: .utf8),
      let nsImage = NSImage(data: data)
    else {
      return NSImage(size: NSSize(width: size, height: size))
    }
    nsImage.size = NSSize(width: size, height: size)
    return nsImage
  }
}
