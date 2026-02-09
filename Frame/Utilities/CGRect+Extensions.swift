import CoreGraphics

extension CGRect {
  var normalized: CGRect {
    CGRect(
      x: min(origin.x, origin.x + size.width),
      y: min(origin.y, origin.y + size.height),
      width: abs(size.width),
      height: abs(size.height)
    )
  }

  func clamped(to bounds: CGRect) -> CGRect {
    let x = max(bounds.minX, min(origin.x, bounds.maxX - width))
    let y = max(bounds.minY, min(origin.y, bounds.maxY - height))
    let w = min(width, bounds.width)
    let h = min(height, bounds.height)
    return CGRect(x: x, y: y, width: w, height: h)
  }
}
