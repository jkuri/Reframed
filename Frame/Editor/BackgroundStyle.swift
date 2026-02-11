import CoreGraphics
import Foundation

enum BackgroundStyle: Sendable, Equatable, Codable {
  case none
  case gradient(Int)
  case solidColor(CodableColor)

  private enum CodingKeys: String, CodingKey {
    case type, gradientId, color
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .none:
      try container.encode("none", forKey: .type)
    case .gradient(let id):
      try container.encode("gradient", forKey: .type)
      try container.encode(id, forKey: .gradientId)
    case .solidColor(let color):
      try container.encode("solidColor", forKey: .type)
      try container.encode(color, forKey: .color)
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    switch type {
    case "gradient":
      let id = try container.decode(Int.self, forKey: .gradientId)
      self = .gradient(id)
    case "solidColor":
      let color = try container.decode(CodableColor.self, forKey: .color)
      self = .solidColor(color)
    default:
      self = .none
    }
  }
}

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
