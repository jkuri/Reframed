import AppKit

struct SelectionRect: Sendable {
  let rect: CGRect
  let displayID: CGDirectDisplayID

  var screenCaptureKitRect: CGRect {
    let screenHeight = CGFloat(CGDisplayPixelsHigh(displayID))
    let w = CGFloat(Int(round(rect.width)) & ~1)
    let h = CGFloat(Int(round(rect.height)) & ~1)
    return CGRect(
      x: round(rect.origin.x),
      y: round(screenHeight - rect.origin.y - h),
      width: w,
      height: h
    )
  }

  var backingScaleFactor: CGFloat {
    NSScreen.screen(for: displayID)?.backingScaleFactor ?? 2.0
  }

  var pixelWidth: Int {
    let w = Int(rect.width * backingScaleFactor)
    return w & ~1
  }

  var pixelHeight: Int {
    let h = Int(rect.height * backingScaleFactor)
    return h & ~1
  }
}
