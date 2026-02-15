import CoreGraphics
import SwiftUI

struct GradientPreset: Identifiable, Sendable {
  let id: Int
  let name: String
  let colors: [Color]
  let startPoint: UnitPoint
  let endPoint: UnitPoint

  var cgColors: [CGColor] {
    colors.map { NSColor($0).cgColor }
  }

  var cgStartPoint: CGPoint {
    CGPoint(x: startPoint.x, y: 1.0 - startPoint.y)
  }

  var cgEndPoint: CGPoint {
    CGPoint(x: endPoint.x, y: 1.0 - endPoint.y)
  }
}

private extension Color {
  init(hex: UInt32) {
    let r = Double((hex >> 16) & 0xFF) / 255.0
    let g = Double((hex >> 8) & 0xFF) / 255.0
    let b = Double(hex & 0xFF) / 255.0
    self.init(red: r, green: g, blue: b)
  }
}

enum GradientPresets {
  static let all: [GradientPreset] = [
    GradientPreset(
      id: 0,
      name: "Hyper",
      colors: [Color(hex: 0xEC4899), Color(hex: 0xEF4444), Color(hex: 0xEAB308)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 1,
      name: "Oceanic",
      colors: [Color(hex: 0x86EFAC), Color(hex: 0x3B82F6), Color(hex: 0x9333EA)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 2,
      name: "Cotton Candy",
      colors: [Color(hex: 0xF9A8D4), Color(hex: 0xD8B4FE), Color(hex: 0x818CF8)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 3,
      name: "Gotham",
      colors: [Color(hex: 0x374151), Color(hex: 0x111827), Color(hex: 0x000000)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 4,
      name: "Sunset",
      colors: [Color(hex: 0xC7D2FE), Color(hex: 0xFECACA), Color(hex: 0xFEF9C3)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 5,
      name: "Mojave",
      colors: [Color(hex: 0xFEF9C3), Color(hex: 0xFDE047), Color(hex: 0xEAB308)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 6,
      name: "Beachside",
      colors: [Color(hex: 0xFEF08A), Color(hex: 0xBBF7D0), Color(hex: 0x22C55E)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 7,
      name: "Gunmetal",
      colors: [Color(hex: 0xE5E7EB), Color(hex: 0x9CA3AF), Color(hex: 0x4B5563)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 8,
      name: "Peachy",
      colors: [Color(hex: 0xFECACA), Color(hex: 0xFCA5A5), Color(hex: 0xFEF08A)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 9,
      name: "Seafoam",
      colors: [Color(hex: 0xBBF7D0), Color(hex: 0x86EFAC), Color(hex: 0x3B82F6)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 10,
      name: "Pumpkin",
      colors: [Color(hex: 0xFEF08A), Color(hex: 0xFACC15), Color(hex: 0xA16207)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 11,
      name: "Pandora",
      colors: [Color(hex: 0xBBF7D0), Color(hex: 0x4ADE80), Color(hex: 0x7E22CE)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 12,
      name: "Valentine",
      colors: [Color(hex: 0xFECACA), Color(hex: 0xDC2626)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 13,
      name: "Hawaii",
      colors: [Color(hex: 0x86EFAC), Color(hex: 0xFDE047), Color(hex: 0xF9A8D4)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 14,
      name: "Lavender",
      colors: [Color(hex: 0xA5B4FC), Color(hex: 0xC084FC)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 15,
      name: "Wintergreen",
      colors: [Color(hex: 0xBBF7D0), Color(hex: 0x22C55E)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 16,
      name: "Huckleberry",
      colors: [Color(hex: 0xE9D5FF), Color(hex: 0xC084FC), Color(hex: 0x6B21A8)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 17,
      name: "Blue Steel",
      colors: [Color(hex: 0x9CA3AF), Color(hex: 0x4B5563), Color(hex: 0x1E40AF)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 18,
      name: "Arendelle",
      colors: [Color(hex: 0xDBEAFE), Color(hex: 0x93C5FD), Color(hex: 0x3B82F6)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 19,
      name: "Spearmint",
      colors: [Color(hex: 0xBBF7D0), Color(hex: 0x4ADE80), Color(hex: 0x22C55E)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 20,
      name: "Minnesota",
      colors: [Color(hex: 0xC084FC), Color(hex: 0xFACC15)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 21,
      name: "Bombpop",
      colors: [Color(hex: 0xF87171), Color(hex: 0xD1D5DB), Color(hex: 0x3B82F6)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 22,
      name: "Acadia",
      colors: [Color(hex: 0x991B1B), Color(hex: 0xCA8A04), Color(hex: 0xEAB308)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 23,
      name: "Sonora",
      colors: [Color(hex: 0xFEF08A), Color(hex: 0xEAB308)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 24,
      name: "Paradise",
      colors: [Color(hex: 0x93C5FD), Color(hex: 0xBBF7D0), Color(hex: 0xFDE047)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 25,
      name: "Sierra Mist",
      colors: [Color(hex: 0xFEF08A), Color(hex: 0xBBF7D0), Color(hex: 0x86EFAC)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 26,
      name: "Creamsicle",
      colors: [Color(hex: 0xFEF08A), Color(hex: 0xFDE047), Color(hex: 0xFACC15)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 27,
      name: "Midnight",
      colors: [Color(hex: 0x1D4ED8), Color(hex: 0x1E40AF), Color(hex: 0x111827)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 28,
      name: "Borealis",
      colors: [Color(hex: 0x86EFAC), Color(hex: 0xC084FC)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 29,
      name: "Strawberry",
      colors: [Color(hex: 0xFEF08A), Color(hex: 0xFBCFE8), Color(hex: 0xF472B6)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 30,
      name: "Flamingo",
      colors: [Color(hex: 0xF472B6), Color(hex: 0xDB2777)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 31,
      name: "Burning Sunrise",
      colors: [Color(hex: 0xCA8A04), Color(hex: 0xDC2626)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 32,
      name: "Apple",
      colors: [Color(hex: 0x22C55E), Color(hex: 0x15803D)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 33,
      name: "Watermelon",
      colors: [Color(hex: 0xEF4444), Color(hex: 0x22C55E)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 34,
      name: "Flare",
      colors: [Color(hex: 0xEA580C), Color(hex: 0xF97316)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 35,
      name: "Rasta",
      colors: [Color(hex: 0x65A30D), Color(hex: 0xFDE047), Color(hex: 0xDC2626)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 36,
      name: "Lust",
      colors: [Color(hex: 0xBE123C), Color(hex: 0xDB2777)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 37,
      name: "Sublime",
      colors: [Color(hex: 0xFB7185), Color(hex: 0xD946EF), Color(hex: 0x6366F1)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 38,
      name: "Witch",
      colors: [Color(hex: 0x0F172A), Color(hex: 0x581C87), Color(hex: 0x0F172A)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 39,
      name: "Powerpuff",
      colors: [Color(hex: 0x38BDF8), Color(hex: 0xFB7185), Color(hex: 0xA3E635)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 40,
      name: "Solid Blue",
      colors: [Color(hex: 0x3B82F6), Color(hex: 0x2563EB)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 41,
      name: "Ice",
      colors: [Color(hex: 0xFFE4E6), Color(hex: 0xCCFBF1)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 42,
      name: "Sky",
      colors: [Color(hex: 0x38BDF8), Color(hex: 0xBAE6FD)],
      startPoint: .top,
      endPoint: .bottom
    ),
    GradientPreset(
      id: 43,
      name: "Horizon",
      colors: [Color(hex: 0xF97316), Color(hex: 0xFDE047)],
      startPoint: .top,
      endPoint: .bottom
    ),
    GradientPreset(
      id: 44,
      name: "Morning",
      colors: [Color(hex: 0xFB7185), Color(hex: 0xFDBA74)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 45,
      name: "Space",
      colors: [Color(hex: 0x111827), Color(hex: 0x4B5563)],
      startPoint: .top,
      endPoint: .bottom
    ),
    GradientPreset(
      id: 46,
      name: "Earth",
      colors: [Color(hex: 0x99F6E4), Color(hex: 0xD9F99D)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 47,
      name: "Picture",
      colors: [Color(hex: 0xD946EF), Color(hex: 0xDC2626), Color(hex: 0xFB923C)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 48,
      name: "Messenger",
      colors: [Color(hex: 0x38BDF8), Color(hex: 0x3B82F6)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 49,
      name: "Sea",
      colors: [Color(hex: 0xA5F3FC), Color(hex: 0x22D3EE)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 50,
      name: "Payment",
      colors: [Color(hex: 0x38BDF8), Color(hex: 0x67E8F9)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 51,
      name: "Video",
      colors: [Color(hex: 0xEF4444), Color(hex: 0x991B1B)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 52,
      name: "Passion",
      colors: [Color(hex: 0xF43F5E), Color(hex: 0xF87171), Color(hex: 0xEF4444)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 53,
      name: "Flower",
      colors: [Color(hex: 0xC4B5FD), Color(hex: 0xA78BFA)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 54,
      name: "Cool Sunset",
      colors: [Color(hex: 0xFDBA74), Color(hex: 0xFDA4AF)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 55,
      name: "Pink Neon",
      colors: [Color(hex: 0xC026D3), Color(hex: 0xDB2777)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 56,
      name: "Blue Sand",
      colors: [Color(hex: 0x64748B), Color(hex: 0xFEF9C3)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 57,
      name: "Emerald",
      colors: [Color(hex: 0x10B981), Color(hex: 0x65A30D)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 58,
      name: "Relaxed Rose",
      colors: [Color(hex: 0xFDA4AF), Color(hex: 0xF43F5E)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 59,
      name: "Purple Haze",
      colors: [Color(hex: 0x6B21A8), Color(hex: 0x4C1D95), Color(hex: 0x6B21A8)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 60,
      name: "Silver",
      colors: [Color(hex: 0xF3F4F6), Color(hex: 0xD1D5DB)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 61,
      name: "Orange Coral",
      colors: [Color(hex: 0xFB923C), Color(hex: 0xFB7185)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 62,
      name: "Blue Coral",
      colors: [Color(hex: 0x60A5FA), Color(hex: 0x34D399)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 63,
      name: "Beam of Light",
      colors: [Color(hex: 0x111827), Color(hex: 0xF3F4F6), Color(hex: 0x111827)],
      startPoint: .top,
      endPoint: .bottom
    ),
    GradientPreset(
      id: 64,
      name: "Safari Sunset",
      colors: [Color(hex: 0xEAB308), Color(hex: 0xA855F7), Color(hex: 0x3B82F6)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 65,
      name: "High Tide",
      colors: [Color(hex: 0x0EA5E9), Color(hex: 0xFED7AA), Color(hex: 0xCA8A04)],
      startPoint: .top,
      endPoint: .bottom
    ),
    GradientPreset(
      id: 66,
      name: "Hunniepop",
      colors: [Color(hex: 0xF0ABFC), Color(hex: 0x4ADE80), Color(hex: 0xBE123C)],
      startPoint: .bottomLeading,
      endPoint: .topTrailing
    ),
    GradientPreset(
      id: 67,
      name: "Soft Metal",
      colors: [Color(hex: 0xC7D2FE), Color(hex: 0x475569), Color(hex: 0xC7D2FE)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 68,
      name: "Coral Sun",
      colors: [Color(hex: 0xFEF08A), Color(hex: 0xA7F3D0), Color(hex: 0xFEF08A)],
      startPoint: .top,
      endPoint: .bottom
    ),
    GradientPreset(
      id: 69,
      name: "Power Pink",
      colors: [Color(hex: 0xF43F5E), Color(hex: 0x4338CA)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 70,
      name: "Powder Blue",
      colors: [Color(hex: 0x38BDF8), Color(hex: 0x1E40AF)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 71,
      name: "Moody Sunset",
      colors: [Color(hex: 0x881337), Color(hex: 0x92400E), Color(hex: 0xFB7185)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 72,
      name: "Burnt Sand",
      colors: [Color(hex: 0xFEF08A), Color(hex: 0xEF4444), Color(hex: 0xD946EF)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 73,
      name: "Blue White Split",
      colors: [Color(hex: 0xFFFFFF), Color(hex: 0x0EA5E9), Color(hex: 0x0EA5E9)],
      startPoint: .bottom,
      endPoint: .top
    ),
    GradientPreset(
      id: 74,
      name: "Purple Beam",
      colors: [Color(hex: 0x312E81), Color(hex: 0x818CF8), Color(hex: 0x312E81)],
      startPoint: .topTrailing,
      endPoint: .bottomLeading
    ),
    GradientPreset(
      id: 75,
      name: "Sand Beam",
      colors: [Color(hex: 0x7C2D12), Color(hex: 0xFEF3C7), Color(hex: 0x7C2D12)],
      startPoint: .top,
      endPoint: .bottom
    ),
    GradientPreset(
      id: 76,
      name: "Island Waves",
      colors: [Color(hex: 0xFACC15), Color(hex: 0xF9FAFB), Color(hex: 0x5EEAD4)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 77,
      name: "Big Sur",
      colors: [Color(hex: 0x8B5CF6), Color(hex: 0xFDBA74)],
      startPoint: .bottomLeading,
      endPoint: .topTrailing
    ),
    GradientPreset(
      id: 78,
      name: "Oahu",
      colors: [Color(hex: 0xFB923C), Color(hex: 0x38BDF8)],
      startPoint: .bottom,
      endPoint: .top
    ),
    GradientPreset(
      id: 79,
      name: "Peach Pie",
      colors: [Color(hex: 0x7F1D1D), Color(hex: 0xDDD6FE), Color(hex: 0xF97316)],
      startPoint: .leading,
      endPoint: .trailing
    ),
    GradientPreset(
      id: 80,
      name: "Salem",
      colors: [Color(hex: 0x111827), Color(hex: 0x581C87), Color(hex: 0x7C3AED)],
      startPoint: .top,
      endPoint: .bottom
    ),
    GradientPreset(
      id: 81,
      name: "Purple Burst",
      colors: [Color(hex: 0x581C87), Color(hex: 0x6366F1)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    ),
    GradientPreset(
      id: 82,
      name: "Amber Sunrise",
      colors: [Color(hex: 0x78350F), Color(hex: 0xFDE047)],
      startPoint: .bottom,
      endPoint: .top
    ),
    GradientPreset(
      id: 83,
      name: "Sky Sea",
      colors: [Color(hex: 0x38BDF8), Color(hex: 0x312E81)],
      startPoint: .trailing,
      endPoint: .leading
    ),
    GradientPreset(
      id: 84,
      name: "Rocket Power",
      colors: [Color(hex: 0xB45309), Color(hex: 0xFDBA74), Color(hex: 0x9F1239)],
      startPoint: .top,
      endPoint: .bottom
    ),
    GradientPreset(
      id: 85,
      name: "Blue Flame",
      colors: [Color(hex: 0xFDE68A), Color(hex: 0x7C3AED), Color(hex: 0x0C4A6E)],
      startPoint: .bottom,
      endPoint: .top
    ),
    GradientPreset(
      id: 86,
      name: "Warm Glow",
      colors: [Color(hex: 0xD1D5DB), Color(hex: 0xC026D3), Color(hex: 0xEA580C)],
      startPoint: .top,
      endPoint: .bottom
    ),
  ]

  static func preset(for id: Int) -> GradientPreset? {
    all.first { $0.id == id }
  }
}
