import SwiftUI

extension SettingsView {
  var recordingContent: some View {
    Group {
      settingsRow(label: "Capture Quality") {
        SegmentPicker(
          items: CaptureQuality.allCases,
          label: { $0.label },
          selection: Binding(
            get: { options?.captureQuality ?? .standard },
            set: { options?.captureQuality = $0 }
          )
        )
      }

      Text(captureQualityDescription)
        .font(.system(size: 11))
        .foregroundStyle(ReframedColors.secondaryText)
        .padding(.top, -10)

      settingsToggle(
        "Retina Capture (Supersample)",
        isOn: Binding(
          get: { options?.retinaCapture ?? false },
          set: { options?.retinaCapture = $0 }
        )
      )

      Text(
        "Doubles capture resolution for better zoom quality. Only enable this on retina displays, otherwise it will result in blurry video."
      )
      .font(.system(size: 11))
      .foregroundStyle(ReframedColors.secondaryText)
      .padding(.top, -10)

      settingsRow(label: "Frame Rate") {
        SegmentPicker(
          items: fpsOptions,
          label: { "\($0)" },
          selection: Binding(
            get: { options?.fps ?? 30 },
            set: { options?.fps = $0 }
          )
        )
      }

      settingsRow(label: "Timer Delay") {
        SegmentPicker(
          items: TimerDelay.allCases,
          label: { $0.label },
          selection: Binding(
            get: { options?.timerDelay ?? .none },
            set: { options?.timerDelay = $0 }
          )
        )
      }
    }
  }

  var captureQualityDescription: String {
    switch options?.captureQuality ?? .standard {
    case .standard: "H.265 (HEVC) 10-bit — great quality, smaller files"
    case .high: "ProRes 422 — near-lossless, larger files"
    case .veryHigh: "ProRes 4444 — lossless quality, massive files"
    }
  }
}
