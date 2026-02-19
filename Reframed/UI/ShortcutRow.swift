import SwiftUI

struct ShortcutRow: View {
  let action: ShortcutAction
  @State private var shortcut: KeyboardShortcut

  init(action: ShortcutAction) {
    self.action = action
    self._shortcut = State(initialValue: ConfigService.shared.shortcut(for: action))
  }

  private var isDefault: Bool {
    shortcut == action.defaultShortcut
  }

  var body: some View {
    HStack {
      Text(action.label)
        .font(.system(size: 13))
        .foregroundStyle(ReframedColors.primaryText)
      Spacer()
      ShortcutRecorderButton(
        shortcut: Binding(
          get: { shortcut },
          set: { newValue in
            shortcut = newValue
            ConfigService.shared.setShortcut(newValue, for: action)
            NotificationCenter.default.post(name: .shortcutsDidChange, object: nil)
          }
        )
      )
      Button {
        shortcut = action.defaultShortcut
        ConfigService.shared.resetShortcut(for: action)
        NotificationCenter.default.post(name: .shortcutsDidChange, object: nil)
      } label: {
        Image(systemName: "arrow.counterclockwise")
          .font(.system(size: 11))
          .foregroundStyle(isDefault ? ReframedColors.disabledText : ReframedColors.dimLabel)
      }
      .buttonStyle(.plain)
      .disabled(isDefault)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 2)
  }
}
