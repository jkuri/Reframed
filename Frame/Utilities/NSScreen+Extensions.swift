import AppKit

extension NSScreen {
  static var unionFrame: CGRect {
    screens.reduce(.zero) { $0.union($1.frame) }
  }

  var displayID: CGDirectDisplayID {
    let key = NSDeviceDescriptionKey("NSScreenNumber")
    return deviceDescription[key] as? CGDirectDisplayID ?? CGMainDisplayID()
  }

  static func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
    screens.first { $0.displayID == displayID }
  }

  static func displayID(for point: CGPoint) -> CGDirectDisplayID {
    var displayCount: UInt32 = 0
    var displayID: CGDirectDisplayID = CGMainDisplayID()
    CGGetDisplaysWithPoint(point, 1, &displayID, &displayCount)
    return displayID
  }
}
