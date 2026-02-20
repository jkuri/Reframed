import SwiftUI

extension SettingsView {
  var generalContent: some View {
    Group {
      appearanceSection
      projectFolderSection
      outputSection
      optionsSection
    }
  }

  var appearanceSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      sectionLabel("Appearance")

      SegmentPicker(
        items: ["system", "light", "dark"],
        label: { $0.capitalized },
        isSelected: { appearance == $0 },
        onSelect: {
          appearance = $0
          ConfigService.shared.appearance = $0
          updateWindowBackgrounds()
        },
        horizontalPadding: 14
      )
    }
  }

  var projectFolderSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      sectionLabel("Project Folder")
      HStack(spacing: 8) {
        Text(projectFolder)
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.primaryText)
          .lineLimit(1)
          .truncationMode(.middle)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
          .background(ReframedColors.fieldBackground)
          .clipShape(RoundedRectangle(cornerRadius: 6))

        Button("Browse") {
          chooseProjectFolder()
        }
        .buttonStyle(SettingsButtonStyle())
      }
    }
  }

  var outputSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      sectionLabel("Output Folder")
      HStack(spacing: 8) {
        Text(outputFolder)
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.primaryText)
          .lineLimit(1)
          .truncationMode(.middle)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
          .background(ReframedColors.fieldBackground)
          .clipShape(RoundedRectangle(cornerRadius: 6))

        Button("Browse") {
          chooseOutputFolder()
        }
        .buttonStyle(SettingsButtonStyle())
      }
    }
  }

  var optionsSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      sectionLabel("Options")

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
