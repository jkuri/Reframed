import SwiftUI

struct ExportSheet: View {
  @Binding var isPresented: Bool
  @State private var settings = ExportSettings()
  let sourceFPS: Int
  let onExport: (ExportSettings) -> Void

  var body: some View {
    VStack(spacing: 0) {
      Text("Export Settings")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(ReframedColors.primaryText)
        .padding(.top, 24)
        .padding(.bottom, 20)

      VStack(alignment: .leading, spacing: 18) {
        settingsRow(label: "Format") {
          Picker("", selection: $settings.format) {
            ForEach(ExportFormat.allCases) { format in
              Text(format.label).tag(format)
            }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
        }

        settingsRow(label: "Codec") {
          Picker("", selection: $settings.codec) {
            ForEach(ExportCodec.allCases) { codec in
              Text(codec.label).tag(codec)
            }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
        }

        Text(settings.codec.description)
          .font(.system(size: 11))
          .foregroundStyle(ReframedColors.dimLabel)
          .padding(.top, -10)

        settingsRow(label: "Frame Rate") {
          Picker("", selection: $settings.fps) {
            ForEach(ExportFPS.allCases) { fps in
              Text(fps.label).tag(fps)
            }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
          .disabled(false)
          .onChange(of: settings.fps) { _, newValue in
            if let fpsVal = newValue.numericValue, fpsVal > sourceFPS {
              settings.fps = .original
            }
          }
        }

        if sourceFPS < 60 {
          Text("Source recorded at \(sourceFPS) fps. Higher frame rates are not available.")
            .font(.system(size: 11))
            .foregroundStyle(ReframedColors.dimLabel)
            .padding(.top, -10)
        }

        settingsRow(label: "Resolution") {
          Picker("", selection: $settings.resolution) {
            ForEach(ExportResolution.allCases) { res in
              Text(res.label).tag(res)
            }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
        }

        settingsRow(label: "Audio Bitrate (kbps)") {
          Picker("", selection: $settings.audioBitrate) {
            ForEach(ExportAudioBitrate.allCases) { bitrate in
              Text(bitrate.label).tag(bitrate)
            }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
        }

        settingsRow(label: "Renderer") {
          Picker("", selection: $settings.mode) {
            ForEach(ExportMode.allCases) { mode in
              Text(mode.label).tag(mode)
            }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
        }

        Text(settings.mode.description)
          .font(.system(size: 11))
          .foregroundStyle(ReframedColors.dimLabel)
          .padding(.top, -10)
      }
      .padding(.horizontal, 28)

      Spacer().frame(height: 28)

      HStack(spacing: 12) {
        Button("Cancel") {
          isPresented = false
        }
        .buttonStyle(ExportSheetButtonStyle(isPrimary: false))

        Button("Export") {
          isPresented = false
          onExport(settings)
        }
        .buttonStyle(ExportSheetButtonStyle(isPrimary: true))
      }
      .padding(.bottom, 24)
    }
    .frame(width: 520)
    .background(ReframedColors.panelBackground)
  }

  private func settingsRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(ReframedColors.secondaryText)
      content()
    }
  }
}

private struct ExportSheetButtonStyle: ButtonStyle {
  let isPrimary: Bool
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .medium))
      .foregroundStyle(isPrimary ? .white : ReframedColors.primaryText)
      .padding(.horizontal, 20)
      .frame(height: 30)
      .background(
        isPrimary
          ? ReframedColors.controlAccentColor
          : (configuration.isPressed ? ReframedColors.buttonPressed : ReframedColors.buttonBackground)
      )
      .clipShape(RoundedRectangle(cornerRadius: 6))
      .opacity(isEnabled ? 1.0 : 0.4)
  }
}
