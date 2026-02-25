import AppKit
import QuartzCore

final class CursorOverlayLayer: CALayer {
  private let cursorLayer = CALayer()
  private var clickLayers: [CALayer] = []
  private var currentStyle: CursorStyle = .defaultArrow
  private var currentSize: CGFloat = 24
  private var cursorVisible = true
  private var clickColor: CGColor?
  private var clickSize: CGFloat = 36
  private var cachedImage: CGImage?
  private var cachedImageStyle: CursorStyle = .defaultArrow
  private var cachedImageSize: CGFloat = 0

  override init() {
    super.init()
    isOpaque = false
    backgroundColor = CGColor.clear
    cursorLayer.isOpaque = false
    cursorLayer.backgroundColor = CGColor.clear
    cursorLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
    addSublayer(cursorLayer)
  }

  override init(layer: Any) {
    super.init(layer: layer)
  }

  required init?(coder: NSCoder) { nil }

  func update(
    pixelPosition: CGPoint,
    style: CursorStyle,
    size: CGFloat,
    visible: Bool,
    containerSize: CGSize,
    clicks: [(point: CGPoint, progress: Double)] = [],
    highlightColor: CGColor? = nil,
    highlightSize: CGFloat = 36
  ) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)

    cursorVisible = visible
    currentStyle = style
    currentSize = size
    clickColor = highlightColor
    clickSize = highlightSize

    frame = CGRect(origin: .zero, size: containerSize)

    if !visible {
      cursorLayer.isHidden = true
      removeClickLayers()
      CATransaction.commit()
      return
    }

    cursorLayer.isHidden = false

    let pad = size * 0.5
    let cursorRect: CGRect
    if style.isCentered {
      cursorRect = CGRect(
        x: pixelPosition.x - size - pad,
        y: pixelPosition.y - size - pad,
        width: (size + pad) * 2,
        height: (size + pad) * 2
      )
    } else {
      cursorRect = CGRect(
        x: pixelPosition.x - pad,
        y: pixelPosition.y - size * 1.5 - pad,
        width: size * 1.5 + pad * 2,
        height: size * 1.5 + pad * 2
      )
    }
    cursorLayer.frame = cursorRect

    let needsImageUpdate = style != cachedImageStyle || abs(size - cachedImageSize) > 0.01
    if needsImageUpdate {
      let scale = NSScreen.main?.backingScaleFactor ?? 2.0
      cursorLayer.contentsScale = scale
      let imgW = Int(cursorRect.width * scale)
      let imgH = Int(cursorRect.height * scale)
      let padPx = pad * scale

      if let cgImage = renderCursorImage(style: style, size: size * scale, padPx: padPx, width: imgW, height: imgH) {
        cursorLayer.contents = cgImage
        cachedImage = cgImage
        cachedImageStyle = style
        cachedImageSize = size
      }
    }

    updateClickLayers(clicks: clicks, containerSize: containerSize)

    CATransaction.commit()
  }

  private func renderCursorImage(
    style: CursorStyle,
    size: CGFloat,
    padPx: CGFloat,
    width: Int,
    height: Int
  )
    -> CGImage?
  {
    let bitmapInfo =
      CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
    guard
      let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: bitmapInfo
      )
    else { return nil }

    ctx.clear(CGRect(x: 0, y: 0, width: width, height: height))
    ctx.translateBy(x: 0, y: CGFloat(height))
    ctx.scaleBy(x: 1, y: -1)

    let drawPoint: CGPoint
    if style.isCentered {
      drawPoint = CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
    } else {
      drawPoint = CGPoint(x: padPx, y: padPx)
    }
    CursorRenderer.drawCursor(in: ctx, position: drawPoint, style: style, size: size, scale: 1.0)
    return ctx.makeImage()
  }

  private func updateClickLayers(
    clicks: [(point: CGPoint, progress: Double)],
    containerSize: CGSize
  ) {
    while clickLayers.count < clicks.count {
      let layer = CALayer()
      layer.isOpaque = false
      layer.backgroundColor = CGColor.clear
      addSublayer(layer)
      clickLayers.append(layer)
    }
    while clickLayers.count > clicks.count {
      clickLayers.last?.removeFromSuperlayer()
      clickLayers.removeLast()
    }

    let scale = NSScreen.main?.backingScaleFactor ?? 2.0

    for (i, click) in clicks.enumerated() {
      let layer = clickLayers[i]
      let maxDiameter = clickSize * 4.0
      let x = click.point.x - maxDiameter / 2
      let y = click.point.y - maxDiameter / 2
      layer.frame = CGRect(x: x, y: y, width: maxDiameter, height: maxDiameter)
      layer.contentsScale = scale

      let imgW = Int(maxDiameter * scale)
      let imgH = Int(maxDiameter * scale)
      let progress = click.progress

      if let cgImage = renderClickImage(
        progress: progress,
        size: clickSize * scale,
        width: imgW,
        height: imgH,
        color: clickColor
      ) {
        layer.contents = cgImage
      }
    }
  }

  private func renderClickImage(
    progress: Double,
    size: CGFloat,
    width: Int,
    height: Int,
    color: CGColor? = nil
  )
    -> CGImage?
  {
    let bitmapInfo =
      CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
    guard
      let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: bitmapInfo
      )
    else { return nil }

    ctx.clear(CGRect(x: 0, y: 0, width: width, height: height))
    CursorRenderer.drawClickHighlight(
      in: ctx,
      position: CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) / 2),
      progress: progress,
      size: size,
      scale: 1.0,
      color: color
    )
    return ctx.makeImage()
  }

  private func removeClickLayers() {
    for layer in clickLayers {
      layer.removeFromSuperlayer()
    }
    clickLayers.removeAll()
  }
}
