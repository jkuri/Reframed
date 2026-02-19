import AppKit
import CoreGraphics
import SwiftUI

struct ColorPreset: Identifiable, Sendable {
  let id: String
  let name: String
  let color: CodableColor

  init(_ name: String, r: CGFloat, g: CGFloat, b: CGFloat) {
    self.id = name
    self.name = name
    self.color = CodableColor(r: r, g: g, b: b)
  }

  var swiftUIColor: Color {
    Color(cgColor: color.cgColor)
  }
}

enum TailwindColors {
  static let all: [ColorPreset] = [
    ColorPreset("Black", r: 0, g: 0, b: 0),
    ColorPreset("White", r: 1, g: 1, b: 1),
    ColorPreset("Amber", r: 0.961, g: 0.620, b: 0.043),
    ColorPreset("Blue", r: 0.231, g: 0.510, b: 0.965),
    ColorPreset("Cyan", r: 0.024, g: 0.714, b: 0.831),
    ColorPreset("Emerald", r: 0.063, g: 0.725, b: 0.506),
    ColorPreset("Fuchsia", r: 0.851, g: 0.275, b: 0.937),
    ColorPreset("Gray", r: 0.420, g: 0.447, b: 0.502),
    ColorPreset("Green", r: 0.133, g: 0.773, b: 0.369),
    ColorPreset("Indigo", r: 0.388, g: 0.400, b: 0.945),
    ColorPreset("Lime", r: 0.518, g: 0.800, b: 0.086),
    ColorPreset("Orange", r: 0.976, g: 0.451, b: 0.086),
    ColorPreset("Pink", r: 0.925, g: 0.282, b: 0.600),
    ColorPreset("Purple", r: 0.659, g: 0.333, b: 0.969),
    ColorPreset("Red", r: 0.937, g: 0.267, b: 0.267),
    ColorPreset("Rose", r: 0.957, g: 0.247, b: 0.369),
    ColorPreset("Sky", r: 0.055, g: 0.647, b: 0.914),
    ColorPreset("Slate", r: 0.392, g: 0.455, b: 0.545),
    ColorPreset("Stone", r: 0.471, g: 0.443, b: 0.424),
    ColorPreset("Teal", r: 0.078, g: 0.722, b: 0.651),
    ColorPreset("Violet", r: 0.545, g: 0.361, b: 0.965),
    ColorPreset("Yellow", r: 0.918, g: 0.702, b: 0.031),
    ColorPreset("Zinc", r: 0.443, g: 0.443, b: 0.478),
  ]
}

@MainActor
enum ReframedColors {
  static var isDark: Bool {
    NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
  }

  static let overlayBackground = NSColor.black.withAlphaComponent(0.5)
  static let selectionBorder = NSColor(white: 0.55, alpha: 0.6)
  static let selectionGrid = NSColor(white: 0.55, alpha: 0.5)
  static let selectionCenter = NSColor(white: 0.65, alpha: 0.6)
  static let handleFill = NSColor(white: 0.15, alpha: 0.9)
  static let handleStroke = NSColor(white: 0.7, alpha: 0.8)
  static let crosshair = NSColor.white.withAlphaComponent(0.3)

  static var panelBackground: Color {
    isDark ? Color(white: 0) : Color(white: 1)
  }

  static var panelBackgroundNS: NSColor {
    isDark ? NSColor(white: 0, alpha: 1) : NSColor(white: 1, alpha: 1)
  }

  static var secondaryTextNS: NSColor {
    isDark ? NSColor.white.withAlphaComponent(0.7) : NSColor.black.withAlphaComponent(0.6)
  }

  static var subtleBorderNS: NSColor {
    isDark ? NSColor.white.withAlphaComponent(0.1) : NSColor.black.withAlphaComponent(0.1)
  }

  static var fieldBackground: Color {
    isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
  }

  static var dimLabel: Color {
    isDark ? Color.white.opacity(0.6) : Color.black.opacity(0.6)
  }

  static var textSelection: Color {
    isDark ? Color(white: 0.35) : Color(white: 0.7)
  }

  static var primaryText: Color {
    isDark ? .white : Color(white: 0)
  }

  static var secondaryText: Color {
    isDark ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
  }

  static var tertiaryText: Color {
    isDark ? Color.white.opacity(0.5) : Color.black.opacity(0.4)
  }

  static var disabledText: Color {
    isDark ? Color.white.opacity(0.7) : Color.black.opacity(0.5)
  }

  static var divider: Color {
    isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.12)
  }

  static var subtleBorder: Color {
    isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
  }

  static var hoverBackground: Color {
    isDark ? Color.white.opacity(0.2) : Color.black.opacity(0.06)
  }

  static var selectedBackground: Color {
    isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
  }

  static var subtleHover: Color {
    isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
  }

  static var selectedActive: Color {
    isDark ? Color.white.opacity(0.2) : Color.black.opacity(0.12)
  }

  static var buttonBackground: Color {
    isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.06)
  }

  static var buttonPressed: Color {
    isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.1)
  }

  static var permissionBorder: Color {
    isDark ? Color.white.opacity(0.2) : Color.black.opacity(0.2)
  }

  static var permissionText: Color {
    isDark ? Color.white.opacity(0.8) : Color.black.opacity(0.7)
  }

  static var controlAccentColor: Color {
    Color(nsColor: .controlAccentColor)
  }

  static let screenTrackColor = Color(red: 0.23, green: 0.51, blue: 0.96)
  static let webcamTrackColor = Color(red: 0.13, green: 0.77, blue: 0.37)

  static let systemAudioColor = Color(red: 0.925, green: 0.282, blue: 0.600)
  static let micAudioColor = Color(red: 0.94, green: 0.27, blue: 0.27)

  static let zoomColor = Color(red: 0.45, green: 0.30, blue: 0.75)
  static let zoomEaseColor = Color(red: 0.45, green: 0.30, blue: 0.75).opacity(0.5)
}
