import SwiftUI

struct InlineEditableText: View {
  let text: String
  let onCommit: (String) -> Void

  @State private var isEditing = false
  @State private var editText = ""
  @FocusState private var isFocused: Bool
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    if isEditing {
      TextField("", text: $editText)
        .font(.system(size: FontSize.xs))
        .foregroundStyle(ReframedColors.primaryText)
        .textFieldStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(ReframedColors.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(ReframedColors.border))
        .focused($isFocused)
        .onSubmit { commit() }
        .onChange(of: isFocused) { _, focused in
          if !focused { commit() }
        }
        .onExitCommand { cancel() }
        .onAppear { isFocused = true }
    } else {
      HStack(spacing: 4) {
        Text(text)
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.primaryText)
          .lineLimit(1)

        Spacer()

        Image(systemName: "pencil")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.secondaryText)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(ReframedColors.fieldBackground.opacity(0.5))
      .clipShape(RoundedRectangle(cornerRadius: Radius.md))
      .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(ReframedColors.border))
      .onTapGesture { startEditing() }
    }
  }

  private func startEditing() {
    editText = text
    isEditing = true
  }

  private func commit() {
    let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty, trimmed != text {
      onCommit(trimmed)
    }
    isEditing = false
  }

  private func cancel() {
    isEditing = false
  }
}
