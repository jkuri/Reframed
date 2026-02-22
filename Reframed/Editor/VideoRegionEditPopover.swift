import SwiftUI

struct VideoRegionEditPopover: View {
  let region: VideoRegionData
  let canRemove: Bool
  let onUpdateTransition: (RegionTransitionType?, Double?, RegionTransitionType?, Double?) -> Void
  let onRemove: () -> Void

  @State private var localEntryTransition: RegionTransitionType = .none
  @State private var localEntryDuration: Double = 0.3
  @State private var localExitTransition: RegionTransitionType = .none
  @State private var localExitDuration: Double = 0.3
  @State private var didInit = false
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    VStack(alignment: .leading, spacing: Layout.regionPopoverSpacing) {
      SectionHeader(title: "Video Region")

      transitionControls

      if canRemove {
        Button {
          onRemove()
        } label: {
          Label("Remove", systemImage: "trash")
        }
        .buttonStyle(OutlineButtonStyle(size: .medium, fullWidth: true))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
      }
    }
    .padding(.vertical, 8)
    .frame(width: Layout.regionPopoverWidth)
    .popoverContainerStyle()
    .onAppear {
      if !didInit {
        localEntryTransition = region.entryTransition ?? .none
        localEntryDuration = region.entryTransitionDuration ?? 0.3
        localExitTransition = region.exitTransition ?? .none
        localExitDuration = region.exitTransitionDuration ?? 0.3
        didInit = true
      }
    }
    .onChange(of: localEntryTransition) { _, newValue in
      onUpdateTransition(newValue, nil, nil, nil)
    }
    .onChange(of: localEntryDuration) { _, newValue in
      onUpdateTransition(nil, newValue, nil, nil)
    }
    .onChange(of: localExitTransition) { _, newValue in
      onUpdateTransition(nil, nil, newValue, nil)
    }
    .onChange(of: localExitDuration) { _, newValue in
      onUpdateTransition(nil, nil, nil, newValue)
    }
  }

  private var transitionControls: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "arrow.right", title: "Entry Transition")

      FullWidthSegmentPicker(
        items: RegionTransitionType.allCases,
        label: { $0.label },
        selection: $localEntryTransition
      )

      if localEntryTransition != .none {
        SliderRow(
          label: "Duration",
          value: $localEntryDuration,
          range: 0.05...1.0,
          step: 0.05,
          formattedValue: String(format: "%.2fs", localEntryDuration)
        )
      }

      Divider()

      SectionHeader(icon: "arrow.left", title: "Exit Transition")

      FullWidthSegmentPicker(
        items: RegionTransitionType.allCases,
        label: { $0.label },
        selection: $localExitTransition
      )

      if localExitTransition != .none {
        SliderRow(
          label: "Duration",
          value: $localExitDuration,
          range: 0.05...1.0,
          step: 0.05,
          formattedValue: String(format: "%.2fs", localExitDuration)
        )
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 4)
  }
}
