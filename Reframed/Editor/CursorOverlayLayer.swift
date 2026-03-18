import AppKit
import QuartzCore

final class CursorOverlayLayer: CALayer {
  private let cursorLayer = CALayer()
  private var ghostLayers: [CALayer] = []
  private var clickLayers: [CALayer] = []
  private var currentStyle: CursorStyle = .centerDefault
  private var currentSize: CGFloat = 24
  private var cursorVisible = true
  private var clickColor: CGColor?
  private var clickSize: CGFloat = 36
  private var cursorFillColor: CodableColor = CodableColor(r: 1, g: 1, b: 1)
  private var cursorStrokeColor: CodableColor = CodableColor(r: 0, g: 0, b: 0)
  private var cachedImage: CGImage?
  private var cachedImageStyle: CursorStyle = .centerDefault
  private var cachedImageSize: CGFloat = 0
  private var cachedFillHex: String = ""
  private var cachedStrokeHex: String = ""
  private var cachedSystemCursorType: SystemCursorType?

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
    highlightSize: CGFloat = 36,
    fillColor: CodableColor = CodableColor(r: 1, g: 1, b: 1),
    strokeColor: CodableColor = CodableColor(r: 0, g: 0, b: 0),
    swayRotation: CGFloat = 0,
    bounceScale: CGFloat = 1.0,
    systemCursorType: SystemCursorType? = nil,
    motionBlurDx: CGFloat = 0,
    motionBlurDy: CGFloat = 0,
    motionBlurMagnitude: CGFloat = 0
  ) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)

    cursorVisible = visible
    currentStyle = style
    currentSize = size
    clickColor = highlightColor
    clickSize = highlightSize
    cursorFillColor = fillColor
    cursorStrokeColor = strokeColor

    frame = CGRect(origin: .zero, size: containerSize)

    if !visible {
      cursorLayer.isHidden = true
      removeClickLayers()
      CATransaction.commit()
      return
    }

    cursorLayer.isHidden = false

    let pad = size * 0.5

    cursorLayer.transform = CATransform3DIdentity

    let wasSystemCursor = cachedSystemCursorType != nil
    if let sysType = systemCursorType {
      let cached = SystemCursorRenderer.cachedImage(for: sysType)
      if let cached {
        let imgScale = size / max(cached.size.width, cached.size.height)
        let w = cached.size.width * imgScale
        let h = cached.size.height * imgScale
        let hx = cached.hotspot.x * imgScale
        let hy = cached.hotspot.y * imgScale
        let cursorRect = CGRect(
          x: pixelPosition.x - hx - pad,
          y: pixelPosition.y - (h - hy) - pad,
          width: w + pad * 2,
          height: h + pad * 2
        )
        cursorLayer.frame = cursorRect
      }
      let needsUpdate = cachedSystemCursorType != sysType || abs(size - cachedImageSize) > 0.01
      if needsUpdate, let cached {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        cursorLayer.contentsScale = scale
        let cursorRect = cursorLayer.frame
        let imgW = Int(cursorRect.width * scale)
        let imgH = Int(cursorRect.height * scale)
        if let cgImage = renderSystemCursorImage(
          cgImage: cached.image,
          cursorSize: cached.size,
          targetSize: size * scale,
          width: imgW,
          height: imgH
        ) {
          cursorLayer.contents = cgImage
          cachedImage = cgImage
          cachedSystemCursorType = sysType
          cachedImageSize = size
        }
      }
    } else {
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
      cachedSystemCursorType = nil
      let fillHex = fillColor.hexString
      let strokeHex = strokeColor.hexString
      let needsImageUpdate =
        wasSystemCursor
        || style != cachedImageStyle || abs(size - cachedImageSize) > 0.01
        || fillHex != cachedFillHex || strokeHex != cachedStrokeHex
      if needsImageUpdate {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        cursorLayer.contentsScale = scale
        let imgW = Int(cursorRect.width * scale)
        let imgH = Int(cursorRect.height * scale)
        let padPx = pad * scale

        if let cgImage = renderCursorImage(
          style: style,
          size: size * scale,
          padPx: padPx,
          width: imgW,
          height: imgH,
          fillColor: fillColor,
          strokeColor: strokeColor
        ) {
          cursorLayer.contents = cgImage
          cachedImage = cgImage
          cachedImageStyle = style
          cachedImageSize = size
          cachedFillHex = fillHex
          cachedStrokeHex = strokeHex
        }
      }
    }

    var cursorTransform = CATransform3DIdentity
    if abs(swayRotation) > 0.001 {
      cursorTransform = CATransform3DRotate(cursorTransform, swayRotation, 0, 0, 1)
    }
    if abs(bounceScale - 1.0) > 0.001 {
      cursorTransform = CATransform3DScale(cursorTransform, bounceScale, bounceScale, 1)
    }
    cursorLayer.transform = cursorTransform

    updateGhostLayers(
      pixelPosition: pixelPosition,
      size: size,
      motionBlurDx: motionBlurDx,
      motionBlurDy: motionBlurDy,
      motionBlurMagnitude: motionBlurMagnitude
    )

    updateClickLayers(clicks: clicks, containerSize: containerSize)

    CATransaction.commit()
  }

  private func renderSystemCursorImage(
    cgImage: CGImage,
    cursorSize: CGSize,
    targetSize: CGFloat,
    width: Int,
    height: Int
  ) -> CGImage? {
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
    let scale = targetSize / max(cursorSize.width, cursorSize.height)
    let w = cursorSize.width * scale
    let h = cursorSize.height * scale
    let cx = CGFloat(width) / 2
    let cy = CGFloat(height) / 2
    let drawRect = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
    ctx.draw(cgImage, in: drawRect)
    return ctx.makeImage()
  }

  private func renderCursorImage(
    style: CursorStyle,
    size: CGFloat,
    padPx: CGFloat,
    width: Int,
    height: Int,
    fillColor: CodableColor,
    strokeColor: CodableColor
  ) -> CGImage? {
    let pixelSize = Int(ceil(size))
    let svg = CursorRenderer.colorizedSVG(
      for: style,
      fillHex: fillColor.hexString,
      strokeHex: strokeColor.hexString
    )
    guard let cursorImage = CursorRenderer.renderSVGToImage(svgString: svg, pixelSize: pixelSize)
    else { return nil }
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
    let drawRect: CGRect
    if style.isCentered {
      let cx = CGFloat(width) / 2
      let cy = CGFloat(height) / 2
      drawRect = CGRect(x: cx - size / 2, y: cy - size / 2, width: size, height: size)
    } else {
      drawRect = CGRect(x: padPx, y: padPx, width: size, height: size)
    }
    ctx.draw(cursorImage, in: drawRect)
    return ctx.makeImage()
  }

  private func updateGhostLayers(
    pixelPosition: CGPoint,
    size: CGFloat,
    motionBlurDx: CGFloat,
    motionBlurDy: CGFloat,
    motionBlurMagnitude: CGFloat
  ) {
    guard motionBlurMagnitude > 1.0 else {
      removeGhostLayers()
      return
    }

    let samples = min(Int(motionBlurMagnitude / 3) + 3, CursorEffects.motionBlurMaxSamples)
    let maxOffset = min(motionBlurMagnitude, CursorEffects.motionBlurMaxOffset)
    let dirX = motionBlurDx / motionBlurMagnitude
    let dirY = motionBlurDy / motionBlurMagnitude
    let ghostCount = samples - 1

    while ghostLayers.count < ghostCount {
      let layer = CALayer()
      layer.isOpaque = false
      layer.backgroundColor = CGColor.clear
      insertSublayer(layer, below: cursorLayer)
      ghostLayers.append(layer)
    }
    while ghostLayers.count > ghostCount {
      ghostLayers.last?.removeFromSuperlayer()
      ghostLayers.removeLast()
    }

    guard let cursorImage = cachedImage else {
      removeGhostLayers()
      return
    }

    for i in 0..<ghostCount {
      let ghost = ghostLayers[i]
      let fraction = CGFloat(ghostCount - i) / CGFloat(samples)
      let offset = maxOffset * fraction
      let alpha = Float((1.0 - fraction) * 0.5)

      let ghostX = pixelPosition.x - dirX * offset
      let ghostY = pixelPosition.y + dirY * offset
      ghost.frame = cursorLayer.frame.offsetBy(
        dx: ghostX - pixelPosition.x,
        dy: ghostY - pixelPosition.y
      )
      ghost.contents = cursorImage
      ghost.contentsScale = cursorLayer.contentsScale
      ghost.opacity = alpha
      ghost.transform = cursorLayer.transform
    }
  }

  private func removeGhostLayers() {
    for layer in ghostLayers {
      layer.removeFromSuperlayer()
    }
    ghostLayers.removeAll()
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
