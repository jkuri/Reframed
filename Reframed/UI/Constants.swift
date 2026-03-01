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

  static let toolbarHeight: CGFloat = 52
  static let toolbarIconSize: CGFloat = FontSize.lg

  static let menuBarWidth: CGFloat = 300
  static let propertiesPanelWidth: CGFloat = 390
  static let editorWindowMinWidth: CGFloat = 1400
  static let editorWindowMinHeight: CGFloat = 900
}

enum Track {
  static let height: CGFloat = 36
  static let borderWidth: CGFloat = 1
  static let borderRadius: CGFloat = Radius.xl
  static let fontSize: CGFloat = FontSize.xs
  static let fontWeight: Font.Weight = .medium
  @MainActor static var background: Color { ReframedColors.backgroundContainer }
  @MainActor static var borderColor: Color { ReframedColors.trackBorder }
  @MainActor static var regionTextColor: Color { ReframedColors.primaryText }
}

enum FontSize {
  static let xxs: CGFloat = 10
  static let xs: CGFloat = 12
  static let sm: CGFloat = 14
  static let base: CGFloat = 16
  static let lg: CGFloat = 18
  static let xl: CGFloat = 20
  static let xxl: CGFloat = 24
  static let xxxl: CGFloat = 30
  static let display: CGFloat = 40
}

enum Radius {
  static let sm: CGFloat = 4
  static let md: CGFloat = 6
  static let lg: CGFloat = 8
  static let xl: CGFloat = 12
  static let xxl: CGFloat = 16
}
