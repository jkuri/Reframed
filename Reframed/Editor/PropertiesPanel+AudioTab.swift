import SwiftUI

extension PropertiesPanel {
  var audioSection: some View {
    VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
      if editorState.hasSystemAudio {
        systemAudioSection
      }
      if editorState.hasMicAudio {
        micAudioSection
      }
    }
  }

  private var systemAudioSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "speaker.wave.2", title: "System Audio")

      ToggleRow(label: "Mute", isOn: $editorState.systemAudioMuted)
        .onChange(of: editorState.systemAudioMuted) { _, _ in
          editorState.syncAudioVolumes()
        }

      SliderRow(
        label: "Volume",
        labelWidth: Layout.labelWidth,
        value: $editorState.systemAudioVolume,
        range: 0...2,
        step: 0.01,
        formattedValue: "\(Int(editorState.systemAudioVolume * 100))%",
        valueWidth: 40
      )
      .onChange(of: editorState.systemAudioVolume) { _, _ in
        editorState.syncAudioVolumes()
      }
      .disabled(editorState.systemAudioMuted)
    }
  }

  private var micAudioSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "mic", title: "Microphone")

      ToggleRow(label: "Mute", isOn: $editorState.micAudioMuted)
        .onChange(of: editorState.micAudioMuted) { _, _ in
          editorState.syncAudioVolumes()
        }

      SliderRow(
        label: "Volume",
        labelWidth: Layout.labelWidth,
        value: $editorState.micAudioVolume,
        range: 0...2,
        step: 0.01,
        formattedValue: "\(Int(editorState.micAudioVolume * 100))%",
        valueWidth: 40
      )
      .onChange(of: editorState.micAudioVolume) { _, _ in
        editorState.syncAudioVolumes()
      }
      .disabled(editorState.micAudioMuted)

      ToggleRow(label: "Noise Reduction", isOn: $editorState.micNoiseReductionEnabled)
        .opacity(editorState.micAudioMuted ? 0.4 : 1.0)
        .disabled(editorState.micAudioMuted)

      if editorState.micNoiseReductionEnabled {
        SliderRow(
          label: "Level",
          labelWidth: Layout.labelWidth,
          value: $editorState.micNoiseReductionIntensity,
          range: 0...1,
          step: 0.01,
          formattedValue: "\(Int(editorState.micNoiseReductionIntensity * 100))%",
          valueWidth: 40
        )
        .disabled(editorState.micAudioMuted)
      }
    }
  }
}
