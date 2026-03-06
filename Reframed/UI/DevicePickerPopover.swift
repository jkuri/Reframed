import SwiftUI

struct DevicePickerPopover: View {
  let title: String
  let emptyMessage: String
  let devices: [DevicePickerItem]
  let selectedId: String?
  let onSelect: (DevicePickerItem) -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    VStack(alignment: .leading, spacing: 0) {
      SectionHeader(title: title)

      if devices.isEmpty {
        Text(emptyMessage)
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.tertiaryText)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
      } else {
        ForEach(devices) { device in
          CheckmarkRow(
            title: device.name,
            isSelected: selectedId == device.id
          ) {
            onSelect(device)
          }
        }
      }
    }
    .padding(.vertical, 8)
    .frame(minWidth: 220)
    .popoverContainerStyle()
  }
}

struct DevicePickerItem: Identifiable {
  let id: String
  let name: String
}
