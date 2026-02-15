import SwiftUI

extension SettingsView {
  var shortcutsContent: some View {
    Group {
      modeSelectionShortcutsSection
      recordingControlsShortcutsSection
      resetAllShortcutsSection
    }
  }

  private var modeSelectionShortcutsSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      sectionLabel("Mode Selection")

      VStack(spacing: 4) {
        ShortcutRow(action: .switchToDisplay)
        ShortcutRow(action: .switchToWindow)
        ShortcutRow(action: .switchToArea)
      }
    }
  }

  private var recordingControlsShortcutsSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      sectionLabel("Recording Controls")

      VStack(spacing: 4) {
        ShortcutRow(action: .stopRecording)
        ShortcutRow(action: .pauseResumeRecording)
        ShortcutRow(action: .restartRecording)
      }
    }
  }

  private var resetAllShortcutsSection: some View {
    HStack {
      Spacer()
      Button("Reset All to Defaults") {
        ConfigService.shared.resetAllShortcuts()
        NotificationCenter.default.post(name: .shortcutsDidChange, object: nil)
      }
      .buttonStyle(SettingsButtonStyle())
    }
    .padding(.horizontal, 28)
  }
}
