import SwiftUI

struct ExportSheet: View {
  @Binding var isPresented: Bool
  @State private var settings = ExportSettings()
  @State private var selectedPreset: ExportPreset = .custom
  let sourceFPS: Int
  let hasAudio: Bool
  let hasCaptions: Bool
  let onExport: (ExportSettings) -> Void
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    VStack(spacing: 0) {
      HStack {
        Text("Export Settings")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(ReframedColors.primaryText)
        Spacer()
      }
      .padding(.horizontal, 28)
      .padding(.top, 24)
      .padding(.bottom, 20)

      VStack(alignment: .leading, spacing: 18) {
        settingsRow(label: "Preset") {
          SegmentPicker(
            items: ExportPreset.allCases,
            label: { $0.label },
            selection: $selectedPreset
          )
        }

        settingsRow(label: "Format") {
          SegmentPicker(
            items: ExportFormat.allCases,
            label: { $0.label },
            selection: manualBinding(\.format)
          )
        }

        if settings.format.isGIF {
          settingsRow(label: "Quality") {
            SegmentPicker(
              items: GIFQuality.allCases,
              label: { $0.label },
              selection: manualBinding(\.gifQuality)
            )
          }

          Text(settings.gifQuality.description)
            .font(.system(size: 11))
            .foregroundStyle(ReframedColors.secondaryText)
            .padding(.top, -10)
        } else {
          settingsRow(label: "Codec") {
            SegmentPicker(
              items: ExportCodec.allCases,
              label: { $0.label },
              selection: manualBinding(\.codec)
            )
          }

          Text(settings.codec.description)
            .font(.system(size: 11))
            .foregroundStyle(ReframedColors.secondaryText)
            .padding(.top, -10)
        }

        settingsRow(label: "Frame Rate") {
          SegmentPicker(
            items: gifAllowedFPSCases,
            label: { $0.label },
            selection: manualBinding(\.fps)
          )
          .onChange(of: settings.fps) { _, newValue in
            if let fpsVal = newValue.numericValue, fpsVal > sourceFPS {
              settings.fps = .original
            }
          }
        }

        if sourceFPS < 60 {
          Text("Source recorded at \(sourceFPS) fps. Higher frame rates are not available.")
            .font(.system(size: 11))
            .foregroundStyle(ReframedColors.secondaryText)
            .padding(.top, -10)
        }

        settingsRow(label: "Resolution") {
          SegmentPicker(
            items: ExportResolution.allCases,
            label: { $0.label },
            selection: manualBinding(\.resolution)
          )
        }

        if hasAudio && !settings.format.isGIF {
          settingsRow(label: "Audio Bitrate (kbps)") {
            SegmentPicker(
              items: ExportAudioBitrate.allCases,
              label: { $0.label },
              selection: manualBinding(\.audioBitrate)
            )
          }
        }

        if !settings.format.isGIF {
          settingsRow(label: "Renderer") {
            SegmentPicker(
              items: ExportMode.allCases,
              label: { $0.label },
              selection: manualBinding(\.mode)
            )
          }

          Text(settings.mode.description)
            .font(.system(size: 11))
            .foregroundStyle(ReframedColors.secondaryText)
            .padding(.top, -10)
        }

        if hasCaptions {
          settingsRow(label: "Captions") {
            SegmentPicker(
              items: CaptionExportMode.allCases,
              label: { $0.label },
              selection: manualBinding(\.captionExportMode)
            )
          }

          Text(settings.captionExportMode.description)
            .font(.system(size: 11))
            .foregroundStyle(ReframedColors.secondaryText)
            .padding(.top, -10)
        }
      }
      .padding(.horizontal, 28)
      .onChange(of: selectedPreset) { _, newPreset in
        if let presetSettings = newPreset.settings {
          settings = presetSettings
        }
      }
      .onChange(of: settings.format) { _, newFormat in
        if newFormat.isGIF {
          if let fpsVal = settings.fps.numericValue, fpsVal > 30 {
            settings.fps = .fps24
          }
        }
        if newFormat == .mp4 && settings.codec.isProRes {
          settings.codec = .h265
        }
      }
      .onChange(of: settings.codec) { _, newCodec in
        if newCodec.isProRes && settings.format != .mov {
          settings.format = .mov
        }
      }

      HStack {
        Spacer()
        HStack(spacing: 8) {
          Button("Cancel") {
            isPresented = false
          }
          .buttonStyle(OutlineButtonStyle(size: .small))

          Button("Export") {
            isPresented = false
            onExport(settings)
          }
          .buttonStyle(PrimaryButtonStyle(size: .small))
        }
      }
      .padding(.horizontal, 28)
      .padding(.top, 20)
      .padding(.bottom, 24)
    }
    .frame(width: 720)
    .background(ReframedColors.backgroundPopover)
  }

  private func manualBinding<T: Equatable>(_ keyPath: WritableKeyPath<ExportSettings, T>) -> Binding<T> {
    Binding(
      get: { settings[keyPath: keyPath] },
      set: { newValue in
        settings[keyPath: keyPath] = newValue
        selectedPreset = .custom
      }
    )
  }

  private var gifAllowedFPSCases: [ExportFPS] {
    if settings.format.isGIF {
      return ExportFPS.allCases.filter { fps in
        guard let val = fps.numericValue else { return true }
        return val <= 30
      }
    }
    return ExportFPS.allCases
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
