import AppKit
import SwiftUI

enum FrameColors {
  static var isDark: Bool {
    NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
  }

  static let overlayBackground = NSColor.black.withAlphaComponent(0.5)
  static let selectionBorder = NSColor(white: 0.55, alpha: 0.6)
  static let selectionGrid = NSColor(white: 0.55, alpha: 0.3)
  static let handleFill = NSColor(white: 0.15, alpha: 0.9)
  static let handleStroke = NSColor(white: 0.7, alpha: 0.8)
  static let crosshair = NSColor.white.withAlphaComponent(0.3)

  static var panelBackground: Color {
    isDark ? Color(white: 0.1) : Color(white: 1)
  }

  static var panelBackgroundNS: NSColor {
    isDark ? NSColor(white: 0.1, alpha: 1) : NSColor(white: 1, alpha: 1)
  }

  static var fieldBackground: Color {
    isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
  }

  static var dimLabel: Color {
    isDark ? Color.white.opacity(0.4) : Color.black.opacity(0.45)
  }

  static var textSelection: Color {
    isDark ? Color(white: 0.35) : Color(white: 0.7)
  }

  static var primaryText: Color {
    isDark ? .white : Color(white: 0.1)
  }

  static var secondaryText: Color {
    isDark ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
  }

  static var tertiaryText: Color {
    isDark ? Color.white.opacity(0.5) : Color.black.opacity(0.4)
  }

  static var divider: Color {
    isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.12)
  }

  static var subtleBorder: Color {
    isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
  }

  static var hoverBackground: Color {
    isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.06)
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
}
