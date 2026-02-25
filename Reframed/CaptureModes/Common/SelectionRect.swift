import AppKit

struct SelectionRect: Sendable {
  let rect: CGRect
  let displayID: CGDirectDisplayID
  let displayOrigin: CGPoint
  let displayHeight: CGFloat

  init(rect: CGRect, displayID: CGDirectDisplayID) {
    self.rect = rect
    self.displayID = displayID
    let screen = NSScreen.screen(for: displayID)
    self.displayOrigin = screen?.frame.origin ?? .zero
    self.displayHeight = screen?.frame.height ?? rect.height
  }

  var screenCaptureKitRect: CGRect {
    let w = CGFloat(Int(round(rect.width)) & ~1)
    let h = CGFloat(Int(round(rect.height)) & ~1)
    let localX = round(rect.origin.x - displayOrigin.x)
    let localAppKitY = rect.origin.y - displayOrigin.y
    let localQuartzY = round(displayHeight - localAppKitY - h)
    return CGRect(x: localX, y: localQuartzY, width: w, height: h)
  }

  var backingScaleFactor: CGFloat {
    NSScreen.screen(for: displayID)?.backingScaleFactor ?? 2.0
  }
}
