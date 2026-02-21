import SwiftUI

enum PrimaryButtonSize {
  case small
  case medium
  case large

  var height: CGFloat {
    switch self {
    case .small: 30
    case .medium: 32
    case .large: 48
    }
  }

  var horizontalPadding: CGFloat {
    switch self {
    case .small: 18
    case .medium: 20
    case .large: 24
    }
  }

  var cornerRadius: CGFloat {
    switch self {
    case .small: Radius.md
    case .medium: Radius.md
    case .large: Radius.xl
    }
  }

  var fontSize: CGFloat {
    switch self {
    case .small: 13
    case .medium: 13
    case .large: 15
    }
  }

  var fontWeight: Font.Weight {
    switch self {
    case .small: .semibold
    case .medium: .semibold
    case .large: .semibold
    }
  }
}

struct PrimaryButtonStyle: ButtonStyle {
  var size: PrimaryButtonSize = .small
  var fullWidth: Bool = false
  var forceLightMode: Bool = false

  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.colorScheme) private var colorScheme

  func makeBody(configuration: Configuration) -> some View {
    let _ = colorScheme
    let bg = forceLightMode ? Color(white: 0.09) : ReframedColors.primary
    let fg = forceLightMode ? Color.white : ReframedColors.primaryForeground
    configuration.label
      .font(.system(size: size.fontSize, weight: size.fontWeight))
      .foregroundStyle(fg)
      .padding(.horizontal, fullWidth ? 0 : size.horizontalPadding)
      .frame(maxWidth: fullWidth ? .infinity : nil)
      .frame(height: size.height)
      .background(configuration.isPressed ? bg.opacity(0.8) : bg)
      .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
      .opacity(isEnabled ? 1.0 : 0.5)
      .hoverEffect(hoverColor: bg.opacity(0.85), cornerRadius: size.cornerRadius)
  }
}

struct SecondaryButtonStyle: ButtonStyle {
  var size: PrimaryButtonSize = .small

  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.colorScheme) private var colorScheme

  func makeBody(configuration: Configuration) -> some View {
    let _ = colorScheme
    configuration.label
      .font(.system(size: size.fontSize, weight: size.fontWeight))
      .foregroundStyle(ReframedColors.primaryText)
      .padding(.horizontal, size.horizontalPadding)
      .frame(height: size.height)
      .background(configuration.isPressed ? ReframedColors.buttonPressed : ReframedColors.buttonBackground)
      .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
      .opacity(isEnabled ? 1.0 : 0.4)
      .hoverEffect(hoverColor: ReframedColors.muted)
  }
}

struct OutlineButtonStyle: ButtonStyle {
  var size: PrimaryButtonSize = .small
  var fullWidth: Bool = false

  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.colorScheme) private var colorScheme

  func makeBody(configuration: Configuration) -> some View {
    let _ = colorScheme
    configuration.label
      .font(.system(size: size.fontSize, weight: size.fontWeight))
      .foregroundStyle(ReframedColors.primaryText)
      .padding(.horizontal, fullWidth ? 0 : size.horizontalPadding)
      .frame(maxWidth: fullWidth ? .infinity : nil)
      .frame(height: size.height)
      .background(configuration.isPressed ? ReframedColors.muted : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
      .overlay(
        RoundedRectangle(cornerRadius: size.cornerRadius)
          .stroke(ReframedColors.border, lineWidth: 1)
      )
      .opacity(isEnabled ? 1.0 : 0.4)
      .hoverEffect(hoverColor: ReframedColors.accent)
  }
}

private struct HoverEffectModifier: ViewModifier {
  let hoverColor: Color
  var cornerRadius: CGFloat = Radius.md
  @State private var isHovered = false

  func body(content: Content) -> some View {
    content
      .background(isHovered ? hoverColor : Color.clear, in: RoundedRectangle(cornerRadius: cornerRadius))
      .onHover { isHovered = $0 }
  }
}

extension View {
  func hoverEffect(hoverColor: Color, cornerRadius: CGFloat = Radius.md) -> some View {
    modifier(HoverEffectModifier(hoverColor: hoverColor, cornerRadius: cornerRadius))
  }
}
