import CoreGraphics
import Foundation

struct PiPLayout: Sendable, Codable {
  var relativeX: CGFloat = 0.02
  var relativeY: CGFloat = 0.02
  var relativeWidth: CGFloat = 0.25

  func pixelRect(screenSize: CGSize, webcamSize: CGSize) -> CGRect {
    let w = screenSize.width * relativeWidth
    let aspect = webcamSize.height / max(webcamSize.width, 1)
    let h = w * aspect
    let x = screenSize.width * relativeX
    let y = screenSize.height * relativeY
    return CGRect(x: x, y: y, width: w, height: h)
  }
}
