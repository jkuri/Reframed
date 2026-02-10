import AppKit

enum ResizeHandle: CaseIterable {
  case topLeft, top, topRight
  case left, right
  case bottomLeft, bottom, bottomRight

  static let size: CGFloat = 12

  func rect(for selectionRect: CGRect) -> CGRect {
    let s = Self.size
    let half = s / 2
    let midX = selectionRect.midX - half
    let midY = selectionRect.midY - half

    switch self {
    case .topLeft: return CGRect(x: selectionRect.minX - half, y: selectionRect.maxY - half, width: s, height: s)
    case .top: return CGRect(x: midX, y: selectionRect.maxY - half, width: s, height: s)
    case .topRight: return CGRect(x: selectionRect.maxX - half, y: selectionRect.maxY - half, width: s, height: s)
    case .left: return CGRect(x: selectionRect.minX - half, y: midY, width: s, height: s)
    case .right: return CGRect(x: selectionRect.maxX - half, y: midY, width: s, height: s)
    case .bottomLeft: return CGRect(x: selectionRect.minX - half, y: selectionRect.minY - half, width: s, height: s)
    case .bottom: return CGRect(x: midX, y: selectionRect.minY - half, width: s, height: s)
    case .bottomRight: return CGRect(x: selectionRect.maxX - half, y: selectionRect.minY - half, width: s, height: s)
    }
  }

  var cursor: NSCursor {
    switch self {
    case .top, .bottom:
      return .resizeUpDown
    case .left, .right:
      return .resizeLeftRight
    case .topLeft, .bottomRight:
      return Self.diagonalNWSECursor
    case .topRight, .bottomLeft:
      return Self.diagonalNESWCursor
    }
  }

  nonisolated(unsafe) private static let diagonalNWSECursor: NSCursor = {
    if let cursor = NSCursor.perform(NSSelectorFromString("_windowResizeNorthWestSouthEastCursor"))?.takeUnretainedValue() as? NSCursor {
      return cursor
    }
    return .resizeUpDown
  }()

  nonisolated(unsafe) private static let diagonalNESWCursor: NSCursor = {
    if let cursor = NSCursor.perform(NSSelectorFromString("_windowResizeNorthEastSouthWestCursor"))?.takeUnretainedValue() as? NSCursor {
      return cursor
    }
    return .resizeUpDown
  }()

  func resize(original: CGRect, delta: CGPoint) -> CGRect {
    var r = original
    switch self {
    case .topLeft:
      r.origin.x += delta.x
      r.size.width -= delta.x
      r.size.height += delta.y
    case .top:
      r.size.height += delta.y
    case .topRight:
      r.size.width += delta.x
      r.size.height += delta.y
    case .left:
      r.origin.x += delta.x
      r.size.width -= delta.x
    case .right:
      r.size.width += delta.x
    case .bottomLeft:
      r.origin.x += delta.x
      r.size.width -= delta.x
      r.origin.y += delta.y
      r.size.height -= delta.y
    case .bottom:
      r.origin.y += delta.y
      r.size.height -= delta.y
    case .bottomRight:
      r.size.width += delta.x
      r.origin.y += delta.y
      r.size.height -= delta.y
    }
    return r
  }
}
