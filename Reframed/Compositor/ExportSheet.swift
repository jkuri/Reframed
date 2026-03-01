import AppKit
import SwiftUI

private enum ExportPhase {
  case settings
  case exporting
  case completed
  case failed
}

struct ExportSheet: View {
  @Bindable var editorState: EditorState
  @Binding var isPresented: Bool
  @State private var settings = ExportSettings()
  @State private var selectedPreset: ExportPreset = .custom
  @State private var phase: ExportPhase = .settings
  @State private var errorMessage = ""
  @State private var exportTask: Task<Void, Never>?
  @Environment(\.colorScheme) private var colorScheme

  private var sourceFPS: Int { editorState.result.fps }

  private var hasAudio: Bool {
    (editorState.hasSystemAudio && !editorState.systemAudioMuted)
      || (editorState.hasMicAudio && !editorState.micAudioMuted)
  }

  private var hasCaptions: Bool {
    editorState.captionsEnabled && !editorState.captionSegments.isEmpty
  }

  var body: some View {
    let _ = colorScheme
    VStack(spacing: 0) {
      switch phase {
      case .settings:
        settingsContent
      case .exporting:
        exportingContent
      case .completed:
        completedContent
      case .failed:
        failedContent
      }
    }
    .frame(width: phase == .settings ? 720 : 520)
    .background(ReframedColors.backgroundPopover)
    .interactiveDismissDisabled(phase == .exporting)
    .onDisappear {
      if phase == .exporting {
        editorState.cancelExport()
      }
      exportTask?.cancel()
      exportTask = nil
    }
  }

  private var settingsContent: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Export Settings")
          .font(.system(size: FontSize.sm, weight: .semibold))
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
            .font(.system(size: FontSize.xs))
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
            .font(.system(size: FontSize.xs))
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
            .font(.system(size: FontSize.xs))
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
            .font(.system(size: FontSize.xs))
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
            .font(.system(size: FontSize.xs))
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
            startExport()
          }
          .buttonStyle(PrimaryButtonStyle(size: .small))
        }
      }
      .padding(.horizontal, 28)
      .padding(.top, 20)
      .padding(.bottom, 24)
    }
  }

  private var exportingContent: some View {
    VStack(spacing: 0) {
      if let statusMessage = editorState.exportStatusMessage {
        Text(statusMessage)
          .font(.system(size: FontSize.xs, weight: .medium).monospacedDigit())
          .foregroundStyle(ReframedColors.secondaryText)
          .padding(.top, 32)
          .padding(.bottom, 24)
      } else {
        Text("Exporting…")
          .font(.system(size: FontSize.sm, weight: .semibold))
          .foregroundStyle(ReframedColors.primaryText)
          .padding(.top, 32)
          .padding(.bottom, 24)

        VStack(spacing: 8) {
          ProgressView(value: editorState.exportProgress)
            .tint(ReframedColors.primaryText)
            .frame(width: 320)

          HStack(spacing: 12) {
            Text("\(Int(editorState.exportProgress * 100))%")
              .font(.system(size: FontSize.xs).monospacedDigit())
              .foregroundStyle(ReframedColors.secondaryText)

            if let eta = editorState.exportETA, eta > 0 {
              Text("ETA \(formatDuration(seconds: Int(ceil(eta))))")
                .font(.system(size: FontSize.xs).monospacedDigit())
                .foregroundStyle(ReframedColors.secondaryText)
            }
          }
        }
        .padding(.bottom, 24)
      }

      Button("Cancel") {
        editorState.cancelExport()
        phase = .settings
      }
      .buttonStyle(OutlineButtonStyle(size: .small))
      .padding(.bottom, 28)
    }
  }

  private var completedContent: some View {
    VStack(spacing: 0) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: FontSize.display))
        .foregroundStyle(ReframedColors.primaryText)
        .padding(.top, 28)
        .padding(.bottom, 12)

      Text("Export Successful")
        .font(.system(size: FontSize.sm, weight: .semibold))
        .foregroundStyle(ReframedColors.primaryText)
        .padding(.bottom, 16)

      if let url = editorState.lastExportedURL {
        VStack(spacing: 6) {
          Text(url.lastPathComponent)
            .font(.system(size: FontSize.xs, weight: .medium))
            .foregroundStyle(ReframedColors.primaryText)
            .lineLimit(1)
            .truncationMode(.middle)

          Text(MediaFileInfo.formattedFileSize(url: url))
            .font(.system(size: FontSize.xs))
            .foregroundStyle(ReframedColors.secondaryText)
        }
        .padding(.bottom, 24)
      }

      HStack(spacing: 12) {
        Button("Copy to Clipboard") {
          copyToClipboard()
        }
        .buttonStyle(OutlineButtonStyle(size: .small))

        Button("Show in Finder") {
          editorState.openExportedFile()
          isPresented = false
        }
        .buttonStyle(OutlineButtonStyle(size: .small))

        Button("Done") {
          isPresented = false
        }
        .buttonStyle(PrimaryButtonStyle(size: .small))
      }
      .padding(.bottom, 28)
    }
  }

  private var failedContent: some View {
    VStack(spacing: 0) {
      Image(systemName: "xmark.circle.fill")
        .font(.system(size: FontSize.display))
        .foregroundStyle(ReframedColors.primaryText)
        .padding(.top, 28)
        .padding(.bottom, 12)

      Text("Export Failed")
        .font(.system(size: FontSize.sm, weight: .semibold))
        .foregroundStyle(ReframedColors.primaryText)
        .padding(.bottom, 12)

      Text(errorMessage)
        .font(.system(size: FontSize.xs))
        .foregroundStyle(ReframedColors.secondaryText)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
        .padding(.bottom, 24)

      HStack(spacing: 12) {
        Button("Back") {
          phase = .settings
        }
        .buttonStyle(OutlineButtonStyle(size: .small))

        Button("Done") {
          isPresented = false
        }
        .buttonStyle(PrimaryButtonStyle(size: .small))
      }
      .padding(.bottom, 28)
    }
  }

  private func startExport() {
    phase = .exporting
    exportTask = Task {
      do {
        let url = try await editorState.export(settings: settings)
        try Task.checkCancellation()
        editorState.lastExportedURL = url
        phase = .completed
      } catch is CancellationError {
      } catch {
        errorMessage = error.localizedDescription
        phase = .failed
      }
    }
    editorState.exportTask = exportTask
  }

  private func copyToClipboard() {
    guard let url = editorState.lastExportedURL else { return }
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.writeObjects([url as NSURL])
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
        .font(.system(size: FontSize.xs, weight: .medium))
        .foregroundStyle(ReframedColors.secondaryText)
      content()
    }
  }
}
