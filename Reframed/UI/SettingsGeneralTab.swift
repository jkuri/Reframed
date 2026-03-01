import SwiftUI

extension SettingsView {
  var generalContent: some View {
    Group {
      settingsRow(label: "Appearance") {
        SegmentPicker(
          items: ["system", "light", "dark"],
          label: { $0.capitalized },
          selection: Binding(
            get: { appearance },
            set: {
              appearance = $0
              ConfigService.shared.appearance = $0
              updateWindowBackgrounds()
            }
          )
        )
      }

      settingsRow(label: "Project Folder") {
        HStack(spacing: 8) {
          Text(projectFolder)
            .font(.system(size: FontSize.xs))
            .foregroundStyle(ReframedColors.primaryText)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(ReframedColors.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(ReframedColors.border))

          Button("Browse") {
            chooseProjectFolder()
          }
          .buttonStyle(OutlineButtonStyle(size: .small))
        }
      }

      settingsRow(label: "Output Folder") {
        HStack(spacing: 8) {
          Text(outputFolder)
            .font(.system(size: FontSize.xs))
            .foregroundStyle(ReframedColors.primaryText)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(ReframedColors.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(ReframedColors.border))

          Button("Browse") {
            chooseOutputFolder()
          }
          .buttonStyle(OutlineButtonStyle(size: .small))
        }
      }

      settingsToggle(
        "Remember Last Selection",
        isOn: Binding(
          get: { options?.rememberLastSelection ?? false },
          set: { options?.rememberLastSelection = $0 }
        )
      )

      settingsToggle(
        "Dim Outer Area While Recording",
        isOn: Binding(
          get: { options?.dimOuterArea ?? true },
          set: { options?.dimOuterArea = $0 }
        )
      )

      settingsToggle(
        "Hide Camera Preview While Recording",
        isOn: Binding(
          get: { options?.hideCameraPreviewWhileRecording ?? false },
          set: { options?.hideCameraPreviewWhileRecording = $0 }
        )
      )
    }
  }
}
