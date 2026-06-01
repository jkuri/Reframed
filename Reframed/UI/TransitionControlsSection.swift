import SwiftUI

struct TransitionControlsSection: View {
  @Binding var entryTransition: RegionTransitionType
  @Binding var entryDuration: Double
  @Binding var exitTransition: RegionTransitionType
  @Binding var exitDuration: Double

  var body: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "arrow.right", title: "Entry Transition")

      SegmentPicker(
        items: RegionTransitionType.allCases,
        label: { $0.label },
        selection: $entryTransition
      )

      if entryTransition != .none {
        SliderRow(
          label: "Duration",
          value: $entryDuration,
          range: 0.05...1.0,
          step: 0.05,
          formattedValue: String(format: "%.2f秒", entryDuration)
        )
      }

      Divider()

      SectionHeader(icon: "arrow.left", title: "Exit Transition")

      SegmentPicker(
        items: RegionTransitionType.allCases,
        label: { $0.label },
        selection: $exitTransition
      )

      if exitTransition != .none {
        SliderRow(
          label: "Duration",
          value: $exitDuration,
          range: 0.05...1.0,
          step: 0.05,
          formattedValue: String(format: "%.2f秒", exitDuration)
        )
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 4)
  }
}
