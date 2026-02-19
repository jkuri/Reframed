import SwiftUI

extension SettingsView {
  var recordingContent: some View {
    Group {
      captureQualitySection
      retinaCaptureSection
      frameRateSection
      timerDelaySection
    }
  }

  var captureQualitySection: some View {
    VStack(alignment: .leading, spacing: Layout.compactSpacing) {
      sectionLabel("Capture Quality")

      HStack {
        Text("Quality")
          .font(.system(size: 13))
          .foregroundStyle(ReframedColors.primaryText)
        Spacer()
        SegmentPicker(
          items: CaptureQuality.allCases,
          label: { $0.label },
          isSelected: { options?.captureQuality == $0 },
          onSelect: { options?.captureQuality = $0 }
        )
      }
      .padding(.horizontal, 10)

      Text(captureQualityDescription)
        .font(.system(size: 11))
        .foregroundStyle(ReframedColors.secondaryText)
        .padding(.horizontal, 10)
    }
  }

  var captureQualityDescription: String {
    switch options?.captureQuality ?? .standard {
    case .standard: "H.264 — good quality, smaller files"
    case .high: "ProRes 422 — near-lossless, larger files"
    case .veryHigh: "ProRes 4444 — lossless quality, massive files"
    }
  }

  var retinaCaptureSection: some View {
    VStack(alignment: .leading, spacing: Layout.compactSpacing) {
      sectionLabel("Retina Capture")

      settingsToggle(
        "Supersample",
        isOn: Binding(
          get: { options?.retinaCapture ?? false },
          set: { options?.retinaCapture = $0 }
        )
      )

      Text("Doubles capture resolution for better zoom quality. Increases file size.")
        .font(.system(size: 11))
        .foregroundStyle(ReframedColors.secondaryText)
        .padding(.horizontal, 10)
    }
  }

  var frameRateSection: some View {
    VStack(alignment: .leading, spacing: Layout.compactSpacing) {
      sectionLabel("Frame Rate")

      HStack {
        Text("FPS")
          .font(.system(size: 13))
          .foregroundStyle(ReframedColors.primaryText)
        Spacer()
        SegmentPicker(
          items: fpsOptions,
          label: { "\($0)" },
          isSelected: { options?.fps == $0 },
          onSelect: { options?.fps = $0 },
          itemWidth: 44
        )
      }
      .padding(.horizontal, 10)
    }
  }

  var timerDelaySection: some View {
    VStack(alignment: .leading, spacing: Layout.compactSpacing) {
      sectionLabel("Timer Delay")

      HStack {
        Text("Countdown")
          .font(.system(size: 13))
          .foregroundStyle(ReframedColors.primaryText)
        Spacer()
        SegmentPicker(
          items: TimerDelay.allCases,
          label: { $0.label },
          isSelected: { options?.timerDelay == $0 },
          onSelect: { options?.timerDelay = $0 }
        )
      }
      .padding(.horizontal, 10)
    }
  }
}
