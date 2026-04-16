import AppKit
import CoreGraphics

enum SystemCursorRenderer {
  private static let cacheLock = NSLock()
  private nonisolated(unsafe) static var imageCache: [SystemCursorType: (image: CGImage, hotspot: CGPoint, size: CGSize)] = [:]

  static func nsCursor(for type: SystemCursorType) -> NSCursor {
    switch type {
    case .arrow: .arrow
    case .iBeam: .iBeam
    case .pointingHand: .pointingHand
    case .crosshair: .crosshair
    case .openHand: .openHand
    case .closedHand: .closedHand
    case .resizeLeftRight: .resizeLeftRight
    case .resizeUpDown: .resizeUpDown
    case .operationNotAllowed: .operationNotAllowed
    case .resizeUp: .resizeUp
    case .resizeDown: .resizeDown
    case .resizeLeft: .resizeLeft
    case .resizeRight: .resizeRight
    case .disappearingItem: .disappearingItem
    case .contextMenu: .contextualMenu
    case .dragCopy: .dragCopy
    case .dragLink: .dragLink
    case .iBeamHorizontal: .iBeamCursorForVerticalLayout
    default: .arrow
    }
  }

  private static let cursorDirNames: [SystemCursorType: String] = [
    .iBeam: "ibeamhorizontal",
    .pointingHand: "pointinghand",
    .crosshair: "cross",
    .openHand: "openhand",
    .closedHand: "closedhand",
    .resizeLeftRight: "resizeleftright",
    .resizeUpDown: "resizeupdown",
    .operationNotAllowed: "notallowed",
    .resizeUp: "resizeup",
    .resizeDown: "resizedown",
    .resizeLeft: "resizeleft",
    .resizeRight: "resizeright",
    .disappearingItem: "poof",
    .contextMenu: "contextualmenu",
    .dragCopy: "copy",
    .dragLink: "makealias",
    .iBeamHorizontal: "ibeamvertical",
    .move: "move",
    .busyButClickable: "busybutclickable",
    .cell: "cell",
    .help: "help",
    .zoomIn: "zoomin",
    .zoomOut: "zoomout",
    .resizeNorth: "resizenorth",
    .resizeSouth: "resizesouth",
    .resizeEast: "resizeeast",
    .resizeWest: "resizewest",
    .resizeNortheast: "resizenortheast",
    .resizeNorthwest: "resizenorthwest",
    .resizeSoutheast: "resizesoutheast",
    .resizeSouthwest: "resizesouthwest",
    .resizeNorthSouth: "resizenorthsouth",
    .resizeEastWest: "resizeeastwest",
    .resizeNortheastSouthwest: "resizenortheastsouthwest",
    .resizeNorthwestSoutheast: "resizenorthwestsoutheast",
    .countingUpHand: "countinguphand",
    .countingDownHand: "countingdownhand",
    .countingUpAndDownHand: "countingupandownhand",
  ]

  private static let cursorsBasePath =
    "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/Resources/cursors"

  private static func loadCursorPDF(for type: SystemCursorType, renderSize: Int) -> CGImage? {
    guard let dirName = cursorDirNames[type] else { return nil }
    let pdfURL = URL(fileURLWithPath: "\(cursorsBasePath)/\(dirName)/cursor.pdf")
    guard let provider = CGDataProvider(url: pdfURL as CFURL),
      let pdfDoc = CGPDFDocument(provider),
      let page = pdfDoc.page(at: 1)
    else { return nil }
    let mediaBox = page.getBoxRect(.mediaBox)
    let scale = CGFloat(renderSize) / max(mediaBox.width, mediaBox.height)
    let w = Int(ceil(mediaBox.width * scale))
    let h = Int(ceil(mediaBox.height * scale))
    let bitmapInfo =
      CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
    guard
      let ctx = CGContext(
        data: nil,
        width: w,
        height: h,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: bitmapInfo
      )
    else { return nil }
    ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: scale, y: scale)
    ctx.drawPDFPage(page)
    return ctx.makeImage()
  }

  static func cachedImage(
    for type: SystemCursorType
  ) -> (image: CGImage, hotspot: CGPoint, size: CGSize)? {
    cacheLock.lock()
    if let cached = imageCache[type] {
      cacheLock.unlock()
      return cached
    }
    cacheLock.unlock()
    let cursor = nsCursor(for: type)
    let hotspot = cursor.hotSpot
    let originalSize = cursor.image.size
    let renderSize = 512
    let cgImage: CGImage
    if let pdfImage = loadCursorPDF(for: type, renderSize: renderSize) {
      cgImage = pdfImage
    } else {
      let renderW = Int(ceil(originalSize.width * 8))
      let renderH = Int(ceil(originalSize.height * 8))
      let bitmapInfo =
        CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
      guard
        let ctx = CGContext(
          data: nil,
          width: renderW,
          height: renderH,
          bitsPerComponent: 8,
          bytesPerRow: 0,
          space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: bitmapInfo
        )
      else { return nil }
      ctx.clear(CGRect(x: 0, y: 0, width: renderW, height: renderH))
      ctx.interpolationQuality = .high
      NSGraphicsContext.saveGraphicsState()
      NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
      cursor.image.draw(
        in: NSRect(x: 0, y: 0, width: renderW, height: renderH),
        from: .zero,
        operation: .sourceOver,
        fraction: 1.0
      )
      NSGraphicsContext.restoreGraphicsState()
      guard let fallback = ctx.makeImage() else { return nil }
      cgImage = fallback
    }
    let entry = (image: cgImage, hotspot: hotspot, size: originalSize)
    cacheLock.lock()
    imageCache[type] = entry
    cacheLock.unlock()
    return entry
  }

  static func drawSystemCursor(
    in context: CGContext,
    position: CGPoint,
    cursorType: SystemCursorType,
    scale: CGFloat,
    rotation: CGFloat = 0,
    bounceScale: CGFloat = 1.0,
    motionBlurDx: CGFloat = 0,
    motionBlurDy: CGFloat = 0,
    motionBlurMagnitude: CGFloat = 0
  ) {
    guard let cached = cachedImage(for: cursorType) else { return }
    let w = cached.size.width * scale * bounceScale
    let h = cached.size.height * scale * bounceScale
    let hx = cached.hotspot.x * scale * bounceScale
    let hy = cached.hotspot.y * scale * bounceScale

    if motionBlurMagnitude > 1.0 {
      let samples = min(Int(motionBlurMagnitude / 3) + 3, CursorEffects.motionBlurMaxSamples)
      let maxOffset = min(motionBlurMagnitude, CursorEffects.motionBlurMaxOffset)
      let dirX = motionBlurDx / motionBlurMagnitude
      let dirY = motionBlurDy / motionBlurMagnitude
      for i in (1..<samples).reversed() {
        let fraction = CGFloat(i) / CGFloat(samples)
        let offset = maxOffset * fraction
        let alpha = (1.0 - fraction) * 0.5
        let offsetPos = CGPoint(x: position.x - dirX * offset, y: position.y - dirY * offset)
        drawSingle(
          in: context,
          image: cached.image,
          position: offsetPos,
          width: w,
          height: h,
          hotspotX: hx,
          hotspotY: hy,
          rotation: rotation,
          alpha: alpha
        )
      }
    }

    drawSingle(
      in: context,
      image: cached.image,
      position: position,
      width: w,
      height: h,
      hotspotX: hx,
      hotspotY: hy,
      rotation: rotation,
      alpha: 1.0
    )
  }

  private static func drawSingle(
    in context: CGContext,
    image: CGImage,
    position: CGPoint,
    width: CGFloat,
    height: CGFloat,
    hotspotX: CGFloat,
    hotspotY: CGFloat,
    rotation: CGFloat,
    alpha: CGFloat
  ) {
    context.saveGState()
    if alpha < 1.0 {
      context.setAlpha(alpha)
    }
    context.translateBy(x: position.x, y: position.y)
    if abs(rotation) > 0.001 {
      context.rotate(by: rotation)
    }
    context.scaleBy(x: 1, y: -1)
    let drawRect = CGRect(x: -hotspotX, y: hotspotY - height, width: width, height: height)
    context.draw(image, in: drawRect)
    context.restoreGState()
  }

  @MainActor static func previewImage(for type: SystemCursorType, size: CGFloat) -> NSImage {
    let cursor = nsCursor(for: type)
    let cursorImage = cursor.image
    let result = NSImage(size: NSSize(width: size, height: size))
    result.lockFocus()
    let scale = min(size / cursorImage.size.width, size / cursorImage.size.height) * 0.8
    let w = cursorImage.size.width * scale
    let h = cursorImage.size.height * scale
    cursorImage.draw(
      in: NSRect(x: (size - w) / 2, y: (size - h) / 2, width: w, height: h),
      from: .zero,
      operation: .sourceOver,
      fraction: 1.0
    )
    result.unlockFocus()
    return result
  }
}
