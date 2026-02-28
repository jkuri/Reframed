import CoreMedia
import SwiftUI

extension PropertiesPanel {
  private var captionLabelWidth: CGFloat { 72 }

  var captionsSection: some View {
    VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
      generateSection
      if !editorState.captionSegments.isEmpty {
        styleSection
        segmentsSection
      }
    }
  }

  private var generateSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "waveform", title: "Generate")

      VStack(alignment: .leading, spacing: Layout.compactSpacing) {
        Text("Model")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
        SegmentPicker(
          items: WhisperModel.allCases,
          label: { $0.shortLabel },
          selection: Binding(
            get: { WhisperModel(rawValue: editorState.captionModel) ?? .base },
            set: { editorState.captionModel = $0.rawValue }
          )
        )
      }

      if let model = WhisperModel(rawValue: editorState.captionModel) {
        Text(model.description)
          .font(.system(size: 11))
          .foregroundStyle(ReframedColors.secondaryText)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
          .frame(minHeight: Layout.compactSpacing, alignment: .top)
      }

      HStack(spacing: 8) {
        Text("Language")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(width: captionLabelWidth, alignment: .leading)
        SelectButton(label: editorState.captionLanguage.label) { dismiss in
          LanguagePicker(
            selection: $editorState.captionLanguage,
            onSelect: dismiss
          )
        }
      }

      if editorState.hasMicAudio && editorState.hasSystemAudio {
        HStack(spacing: 8) {
          Text("Source")
            .font(.system(size: 12))
            .foregroundStyle(ReframedColors.secondaryText)
            .frame(width: captionLabelWidth, alignment: .leading)
          SegmentPicker(
            items: CaptionAudioSource.allCases,
            label: { $0.label },
            selection: $editorState.captionAudioSource
          )
        }
      }

      if WhisperModelManager.shared.isDownloading {
        VStack(spacing: 4) {
          HStack(spacing: 8) {
            ProgressView(value: WhisperModelManager.shared.downloadProgress)
              .tint(ReframedColors.primaryText)
            Text("\(Int(WhisperModelManager.shared.downloadProgress * 100))%")
              .font(.system(size: 11).monospacedDigit())
              .foregroundStyle(ReframedColors.secondaryText)
              .frame(width: 32, alignment: .trailing)
          }
          HStack {
            Text("Downloading model…")
              .font(.system(size: 11))
              .foregroundStyle(ReframedColors.secondaryText)
            Spacer()
            Button("Cancel") {
              WhisperModelManager.shared.cancelDownload()
            }
            .buttonStyle(OutlineButtonStyle(size: .small))
          }
        }
      }

      if editorState.isTranscribing {
        VStack(spacing: 4) {
          HStack(spacing: 8) {
            ProgressView(value: editorState.transcriptionProgress)
              .tint(ReframedColors.primaryText)
            Text("\(Int(editorState.transcriptionProgress * 100))%")
              .font(.system(size: 11).monospacedDigit())
              .foregroundStyle(ReframedColors.secondaryText)
              .frame(width: 32, alignment: .trailing)
          }
          HStack {
            Text(transcriptionStatusText)
              .font(.system(size: 11))
              .foregroundStyle(ReframedColors.secondaryText)
            Spacer()
            Button("Cancel") {
              editorState.cancelTranscription()
            }
            .buttonStyle(OutlineButtonStyle(size: .small))
          }
        }
      } else {
        HStack(spacing: 8) {
          Button(
            editorState.captionSegments.isEmpty && !editorState.transcriptionDidFinishEmpty
              ? "Generate Captions" : "Regenerate"
          ) {
            handleGenerateAction()
          }
          .buttonStyle(PrimaryButtonStyle(size: .small, fullWidth: true))

          if !editorState.captionSegments.isEmpty {
            Button("Clear") {
              editorState.clearCaptions()
            }
            .buttonStyle(OutlineButtonStyle(size: .small, fullWidth: true))
          }
        }

        if editorState.transcriptionDidFinishEmpty {
          HStack(spacing: 6) {
            Image(systemName: "text.badge.xmark")
              .font(.system(size: 12))
              .foregroundStyle(ReframedColors.secondaryText)
            Text("No speech detected in the audio.")
              .font(.system(size: 11))
              .foregroundStyle(ReframedColors.secondaryText)
          }
        }
      }
    }
  }

  private var transcriptionStatusText: String {
    let pct = Int(editorState.transcriptionProgress * 100)
    if editorState.transcriptionProgress < 0.15 {
      return "Loading model… \(pct)%"
    }
    return "Transcribing… \(pct)%"
  }

  private func handleGenerateAction() {
    guard let model = WhisperModel(rawValue: editorState.captionModel) else { return }
    if WhisperModelManager.shared.isDownloaded(model) {
      editorState.generateCaptions()
    } else {
      Task {
        do {
          try await WhisperModelManager.shared.downloadModel(model)
          editorState.generateCaptions()
        } catch {}
      }
    }
  }

  private var styleSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "textformat", title: "Style")

      ToggleRow(label: "Enabled", isOn: $editorState.captionsEnabled)

      SliderRow(
        label: "Size",
        labelWidth: captionLabelWidth,
        value: $editorState.captionFontSize,
        range: 16...96,
        step: 2,
        formattedValue: "\(Int(editorState.captionFontSize))px",
        valueWidth: 40
      )
      .disabled(!editorState.captionsEnabled)

      VStack(alignment: .leading, spacing: Layout.compactSpacing) {
        Text("Weight")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
        SegmentPicker(
          items: CaptionFontWeight.allCases,
          label: { $0.label },
          selection: $editorState.captionFontWeight
        )
      }
      .disabled(!editorState.captionsEnabled)

      VStack(alignment: .leading, spacing: Layout.compactSpacing) {
        Text("Position")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
        SegmentPicker(
          items: CaptionPosition.allCases,
          label: { $0.label },
          selection: $editorState.captionPosition
        )
      }
      .disabled(!editorState.captionsEnabled)

      ToggleRow(label: "Background", isOn: $editorState.captionShowBackground)
        .disabled(!editorState.captionsEnabled)

      HStack(spacing: 8) {
        Text("Text")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(width: captionLabelWidth, alignment: .leading)
        captionTextColorPicker
      }
      .disabled(!editorState.captionsEnabled)

      if editorState.captionShowBackground {
        HStack(spacing: 8) {
          Text("Background")
            .font(.system(size: 12))
            .foregroundStyle(ReframedColors.secondaryText)
            .frame(width: captionLabelWidth, alignment: .leading)
          captionBgColorPicker
        }
        .disabled(!editorState.captionsEnabled)

        SliderRow(
          label: "Opacity",
          labelWidth: captionLabelWidth,
          value: $editorState.captionBackgroundOpacity,
          range: 0.1...1.0,
          step: 0.05,
          formattedValue: "\(Int(editorState.captionBackgroundOpacity * 100))%",
          valueWidth: 40
        )
        .disabled(!editorState.captionsEnabled)
      }

      SliderRow(
        label: "Words",
        labelWidth: captionLabelWidth,
        value: Binding(
          get: { CGFloat(editorState.captionMaxWordsPerLine) },
          set: { editorState.captionMaxWordsPerLine = Int($0) }
        ),
        range: 2...12,
        step: 1,
        formattedValue: "\(editorState.captionMaxWordsPerLine)",
        valueWidth: 40
      )
      .disabled(!editorState.captionsEnabled)
    }
  }

  @ViewBuilder
  private var captionTextColorPicker: some View {
    let currentColor = editorState.captionTextColor
    TailwindColorPicker(
      displayColor: Color(cgColor: currentColor.cgColor),
      displayName: TailwindColors.all.first(where: { $0.color == currentColor })?.id ?? "Custom",
      isSelected: { $0.color == currentColor },
      onSelect: { editorState.captionTextColor = $0.color }
    )
  }

  @ViewBuilder
  private var captionBgColorPicker: some View {
    let currentColor = editorState.captionBackgroundColor
    TailwindColorPicker(
      displayColor: Color(cgColor: currentColor.cgColor),
      displayName: TailwindColors.all.first(where: { $0.color == currentColor })?.id ?? "Custom",
      isSelected: { $0.color == currentColor },
      onSelect: { editorState.captionBackgroundColor = $0.color }
    )
  }

  private var segmentsSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      Button {
        withAnimation(.easeInOut(duration: 0.2)) {
          captionSegmentsExpanded.toggle()
        }
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "list.bullet")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(ReframedColors.accent)
          Text("Segments (\(editorState.captionSegments.count))")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(ReframedColors.primaryText)
          Spacer()
          Image(systemName: captionSegmentsExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(ReframedColors.secondaryText)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      if captionSegmentsExpanded {
        ScrollView {
          LazyVStack(spacing: 2) {
            ForEach(editorState.captionSegments) { segment in
              CaptionSegmentRow(
                segment: segment,
                onSeek: {
                  editorState.pause()
                  editorState.seek(
                    to: CMTime(seconds: segment.startSeconds, preferredTimescale: 600)
                  )
                }
              )
            }
          }
        }
        .frame(maxHeight: 300)
      }
    }
  }
}
