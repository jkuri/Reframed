import SwiftUI

struct NumberField: View {
  @Binding var value: Int
  var width: CGFloat = 70
  var height: CGFloat = 40
  var fontSize: CGFloat = FontSize.xs
  var onCommit: (() -> Void)?
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    TextField("", value: $value, format: .number)
      .textFieldStyle(.plain)
      .font(.system(size: fontSize, design: .monospaced))
      .foregroundStyle(ReframedColors.primaryText)
      .tint(ReframedColors.textSelection)
      .multilineTextAlignment(.center)
      .frame(width: width, height: height)
      .background(ReframedColors.fieldBackground)
      .clipShape(RoundedRectangle(cornerRadius: Radius.md))
      .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(ReframedColors.border))
      .onSubmit { onCommit?() }
  }
}
