import SwiftUI

struct NumberField: View {
  @Binding var value: Int
  var width: CGFloat = 70
  var height: CGFloat = 40
  var fontSize: CGFloat = 14
  var onCommit: (() -> Void)?

  var body: some View {
    TextField("", value: $value, format: .number)
      .textFieldStyle(.plain)
      .font(.system(size: fontSize, design: .monospaced))
      .foregroundStyle(FrameColors.primaryText)
      .tint(FrameColors.textSelection)
      .multilineTextAlignment(.center)
      .frame(width: width, height: height)
      .background(FrameColors.fieldBackground)
      .clipShape(RoundedRectangle(cornerRadius: 6))
      .onSubmit { onCommit?() }
  }
}
