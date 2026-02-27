import CoreGraphics
import Foundation

enum CameraBackgroundStyle: Sendable, Equatable, Codable {
  case none
  case blur(CGFloat)
  case solidColor(CodableColor)
  case gradient(Int)
  case image(String)

  private enum CodingKeys: String, CodingKey {
    case type, intensity, color, gradientId, filename
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .none:
      try container.encode("none", forKey: .type)
    case .blur(let intensity):
      try container.encode("blur", forKey: .type)
      try container.encode(intensity, forKey: .intensity)
    case .solidColor(let color):
      try container.encode("solidColor", forKey: .type)
      try container.encode(color, forKey: .color)
    case .gradient(let id):
      try container.encode("gradient", forKey: .type)
      try container.encode(id, forKey: .gradientId)
    case .image(let filename):
      try container.encode("image", forKey: .type)
      try container.encode(filename, forKey: .filename)
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    switch type {
    case "blur":
      let intensity = try container.decode(CGFloat.self, forKey: .intensity)
      self = .blur(intensity)
    case "solidColor":
      let color = try container.decode(CodableColor.self, forKey: .color)
      self = .solidColor(color)
    case "gradient":
      let id = try container.decode(Int.self, forKey: .gradientId)
      self = .gradient(id)
    case "image":
      let filename = try container.decode(String.self, forKey: .filename)
      self = .image(filename)
    default:
      self = .none
    }
  }
}
