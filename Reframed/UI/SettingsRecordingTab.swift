import SwiftUI

extension SettingsView {
  var recordingContent: some View {
    Group {
      frameRateSection
      timerDelaySection
    }
  }

  var frameRateSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
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
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
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
