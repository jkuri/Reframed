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

