import SwiftUI

struct DevicePopover: View {
  let onStart: (String) -> Void

  @State private var selectedDeviceId: String?

  private var devices: [ExternalDevice] {
    DeviceDiscovery.shared.availableDevices
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if devices.isEmpty {
        emptyState
      } else {
        deviceList
      }

      Text("Make sure your device is unlocked before recording")
        .font(.system(size: 11))
        .foregroundStyle(ReframedColors.tertiaryText)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)

      Button {
        guard let id = selectedDeviceId else { return }
        onStart(id)
      } label: {
        HStack(spacing: 5) {
          Image(systemName: "record.circle")
            .font(.system(size: 12, weight: .semibold))
          Text("Start Recording")
            .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(Color(nsColor: .controlAccentColor))
        .clipShape(RoundedRectangle(cornerRadius: 7))
      }
      .buttonStyle(.plain)
      .disabled(selectedDeviceId == nil)
      .opacity(1)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
    }
    .padding(.vertical, 8)
    .frame(width: 300)
    .background(ReframedColors.panelBackground)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .strokeBorder(ReframedColors.subtleBorder, lineWidth: 0.5)
    )
    .onChange(of: devices) {
      if devices.count == 1 {
        selectedDeviceId = devices.first?.id
      } else if let sel = selectedDeviceId, !devices.contains(where: { $0.id == sel }) {
        selectedDeviceId = nil
      }
    }
    .onAppear {
      DeviceDiscovery.shared.refreshDevices()
      if devices.count == 1 {
        selectedDeviceId = devices.first?.id
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 6) {
      Image(systemName: "iphone")
        .font(.system(size: 28))
        .foregroundStyle(ReframedColors.tertiaryText)
      Text("No devices found")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(ReframedColors.primaryText)
      Text("Connect via USB and unlock")
        .font(.system(size: 11))
        .foregroundStyle(ReframedColors.tertiaryText)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 16)
  }

  private var deviceList: some View {
    VStack(alignment: .leading, spacing: 6) {
      SectionHeader(title: "Device")

      ForEach(devices) { device in
        DeviceRow(
          device: device,
          isSelected: selectedDeviceId == device.id
        ) {
          selectedDeviceId = device.id
        }
        .padding(.horizontal, 12)
      }
    }
  }
}

private struct DeviceRow: View {
  let device: ExternalDevice
  let isSelected: Bool
  let action: () -> Void

  @State private var isHovered = false

  private var isIPad: Bool {
    device.modelID.lowercased().contains("ipad")
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: isIPad ? "ipad" : "iphone")
          .font(.system(size: 20))
          .foregroundStyle(isSelected ? Color(nsColor: .controlAccentColor) : ReframedColors.secondaryText)
          .frame(width: 28)

        VStack(alignment: .leading, spacing: 1) {
          Text(device.name)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(ReframedColors.primaryText)
            .lineLimit(1)

          Text(isIPad ? "iPad" : "iPhone")
            .font(.system(size: 11))
            .foregroundStyle(ReframedColors.tertiaryText)
        }

        Spacer()

        if isSelected {
          Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color(nsColor: .controlAccentColor))
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 7)
          .strokeBorder(
            isSelected ? Color(nsColor: .controlAccentColor).opacity(0.6) : ReframedColors.subtleBorder,
            lineWidth: isSelected ? 1.5 : 0.5
          )
          .background(
            RoundedRectangle(cornerRadius: 7)
              .fill(
                isSelected ? Color(nsColor: .controlAccentColor).opacity(0.08) : (isHovered ? ReframedColors.hoverBackground : Color.clear)
              )
          )
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
  }
}
