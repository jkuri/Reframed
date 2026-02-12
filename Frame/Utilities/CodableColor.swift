import CoreGraphics

struct CodableColor: Sendable, Equatable, Codable {
  let r: CGFloat
  let g: CGFloat
  let b: CGFloat
  let a: CGFloat

  var cgColor: CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
  }

  init(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1.0) {
    self.r = r
    self.g = g
    self.b = b
    self.a = a
  }

  init(cgColor: CGColor) {
    let components = cgColor.components ?? [0, 0, 0, 1]
    if components.count >= 4 {
      self.r = components[0]
      self.g = components[1]
      self.b = components[2]
      self.a = components[3]
    } else if components.count >= 2 {
      self.r = components[0]
      self.g = components[0]
      self.b = components[0]
      self.a = components[1]
    } else {
      self.r = 0
      self.g = 0
      self.b = 0
      self.a = 1
    }
  }
}
