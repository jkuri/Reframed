import AppKit
import SwiftUI

enum Window {
  static let sharingType: NSWindow.SharingType = .none
}

enum Layout {
  static let sectionSpacing: CGFloat = 32
  static let itemSpacing: CGFloat = 16
  static let compactSpacing: CGFloat = 8
  static let gridSpacing: CGFloat = 8
  static let panelPadding: CGFloat = 16
  static let settingsPadding: CGFloat = 28
  static let labelWidth: CGFloat = 42

  static let regionPopoverWidth: CGFloat = 320
  static let regionPopoverSpacing: CGFloat = 4

  static let segmentSpacing: CGFloat = 8

  static let menuBarWidth: CGFloat = 340
  static let propertiesPanelWidth: CGFloat = 390
  static let editorWindowMinWidth: CGFloat = 1300
  static let editorWindowMinHeight: CGFloat = 900
}

enum Track {
  static let height: CGFloat = 42
  static let borderWidth: CGFloat = 2
  static let borderRadius: CGFloat = Radius.lg
  static let fontSize: CGFloat = 10
  static let fontWeight: Font.Weight = .medium
  @MainActor static var background: Color { ReframedColors.backgroundContainer }
  @MainActor static var borderColor: Color { ReframedColors.trackBorder }
  @MainActor static var regionTextColor: Color { ReframedColors.primaryText }
}

enum Radius {
  static let sm: CGFloat = 4
  static let md: CGFloat = 6
  static let lg: CGFloat = 8
  static let xl: CGFloat = 10
}
