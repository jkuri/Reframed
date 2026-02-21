import SwiftUI

struct ExportSheet: View {
  @Binding var isPresented: Bool
  @State private var settings = ExportSettings()
  let sourceFPS: Int
  let hasAudio: Bool
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
        settingsRow(label: "Format") {
          FullWidthSegmentPicker(
            items: ExportFormat.allCases,
            label: { $0.label },
            selection: $settings.format
          )
        }

        if settings.format.isGIF {
          settingsRow(label: "Quality") {
            FullWidthSegmentPicker(
              items: GIFQuality.allCases,
              label: { $0.label },
              selection: $settings.gifQuality
            )
          }

          Text(settings.gifQuality.description)
            .font(.system(size: 11))
            .foregroundStyle(ReframedColors.dimLabel)
            .padding(.top, -10)
        } else {
          settingsRow(label: "Codec") {
            FullWidthSegmentPicker(
              items: ExportCodec.allCases,
              label: { $0.label },
              selection: $settings.codec
            )
          }

          Text(settings.codec.description)
            .font(.system(size: 11))
            .foregroundStyle(ReframedColors.dimLabel)
            .padding(.top, -10)
        }

        settingsRow(label: "Frame Rate") {
          FullWidthSegmentPicker(
            items: gifAllowedFPSCases,
            label: { $0.label },
            selection: $settings.fps
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
            .foregroundStyle(ReframedColors.dimLabel)
            .padding(.top, -10)
        }

        settingsRow(label: "Resolution") {
          FullWidthSegmentPicker(
            items: ExportResolution.allCases,
            label: { $0.label },
            selection: $settings.resolution
          )
        }

        if hasAudio && !settings.format.isGIF {
          settingsRow(label: "Audio Bitrate (kbps)") {
            FullWidthSegmentPicker(
              items: ExportAudioBitrate.allCases,
              label: { $0.label },
              selection: $settings.audioBitrate
            )
          }
        }

        if !settings.format.isGIF {
          settingsRow(label: "Renderer") {
            FullWidthSegmentPicker(
              items: ExportMode.allCases,
              label: { $0.label },
              selection: $settings.mode
            )
          }

          Text(settings.mode.description)
            .font(.system(size: 11))
            .foregroundStyle(ReframedColors.dimLabel)
            .padding(.top, -10)
        }
      }
      .padding(.horizontal, 28)
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
    .frame(width: 520)
    .background(ReframedColors.backgroundPopover)
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
