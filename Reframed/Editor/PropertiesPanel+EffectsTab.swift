import AVFoundation
import SwiftUI

extension PropertiesPanel {
  var spotlightSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "light.max", title: "Spotlight")

      if editorState.cursorMetadataProvider == nil {
        Text("Requires cursor data to be recorded.")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        ToggleRow(label: "Enable Spotlight", isOn: $editorState.spotlightEnabled)

        if editorState.spotlightEnabled {
          SliderRow(
            label: "Radius",
            labelWidth: 58,
            value: $editorState.spotlightRadius,
            range: 50...500,
            step: 10,
            formattedValue: "\(Int(editorState.spotlightRadius))px",
            valueWidth: 40
          )

          SliderRow(
            label: "Dim",
            labelWidth: 58,
            value: $editorState.spotlightDimOpacity,
            range: 0.1...0.95,
            step: 0.05,
            formattedValue: "\(Int(editorState.spotlightDimOpacity * 100))%",
            valueWidth: 40
          )

          SliderRow(
            label: "Softness",
            labelWidth: 58,
            value: $editorState.spotlightEdgeSoftness,
            range: 0...200,
            step: 5,
            formattedValue: "\(Int(editorState.spotlightEdgeSoftness))px",
            valueWidth: 40
          )
        }
      }
    }
  }

  var clickSoundSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "speaker.wave.1", title: "Click Sound")

      if editorState.cursorMetadataProvider == nil {
        Text("Requires cursor data to be recorded.")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        ToggleRow(label: "Enable Click Sound", isOn: $editorState.clickSoundEnabled)

        if editorState.clickSoundEnabled {
          HStack(spacing: 8) {
            Text("Sound")
              .font(.system(size: FontSize.xs))
              .foregroundStyle(ReframedColors.secondaryText)
              .frame(width: Layout.labelWidth, alignment: .leading)

            Dropdown(
              selectedLabel: editorState.clickSoundStyle.label,
              selection: $editorState.clickSoundStyle
            ) {
              ForEach(ClickSoundCategory.allCases, id: \.self) { category in
                Section(category.label) {
                  ForEach(ClickSoundStyle.styles(for: category)) { style in
                    Button(style.label) {
                      editorState.clickSoundStyle = style
                    }
                  }
                }
              }
            }

            Button {
              previewClickSound()
            } label: {
              Image(systemName: "play.fill")
                .font(.system(size: FontSize.xs))
            }
            .buttonStyle(OutlineButtonStyle(size: .small))
          }

          SliderRow(
            label: "Volume",
            labelWidth: Layout.labelWidth,
            value: Binding(
              get: { CGFloat(editorState.clickSoundVolume) },
              set: { editorState.clickSoundVolume = Float($0) }
            ),
            range: 0.1...1.0,
            step: 0.05,
            formattedValue: "\(Int(editorState.clickSoundVolume * 100))%",
            valueWidth: 40
          )
        }
      }
    }
  }

  private func previewClickSound() {
    guard let data = Data(base64Encoded: editorState.clickSoundStyle.base64Data) else { return }
    clickSoundPreviewPlayer = try? AVAudioPlayer(data: data)
    clickSoundPreviewPlayer?.volume = editorState.clickSoundVolume
    clickSoundPreviewPlayer?.play()
  }
}
