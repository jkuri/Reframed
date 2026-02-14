import SwiftUI

extension SettingsView {
  var devicesContent: some View {
    Group {
      audioSection
      cameraSectionView
    }
  }

  var microphoneLabel: String {
    guard let id = options?.selectedMicrophone?.id else { return "None" }
    return availableMicrophones.first { $0.id == id }?.name ?? "None"
  }

  var audioSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      sectionLabel("Audio")

      settingsToggle(
        "Capture System Audio",
        isOn: Binding(
          get: { options?.captureSystemAudio ?? false },
          set: { options?.captureSystemAudio = $0 }
        )
      )

      HStack {
        Text("Microphone")
          .font(.system(size: 13))
          .foregroundStyle(ReframedColors.primaryText)
        Spacer()
        devicePickerButton(label: microphoneLabel, isActive: $showMicPopover)
          .popover(isPresented: $showMicPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
              CheckmarkRow(title: "None", isSelected: options?.selectedMicrophone == nil) {
                options?.selectedMicrophone = nil
                showMicPopover = false
              }
              ForEach(availableMicrophones) { mic in
                CheckmarkRow(title: mic.name, isSelected: options?.selectedMicrophone?.id == mic.id) {
                  options?.selectedMicrophone = mic
                  showMicPopover = false
                }
              }
            }
            .padding(.vertical, 8)
            .frame(width: 220)
            .background(ReframedColors.panelBackground)
          }
          .presentationBackground(ReframedColors.panelBackground)
      }
      .padding(.horizontal, 10)
    }
  }

  var cameraLabelText: String {
    guard let id = options?.selectedCamera?.id else { return "None" }
    return availableCameras.first { $0.id == id }?.name ?? "None"
  }

  var cameraSectionView: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      sectionLabel("Camera")

      HStack {
        Text("Camera Device")
          .font(.system(size: 13))
          .foregroundStyle(ReframedColors.primaryText)
        Spacer()
        devicePickerButton(label: cameraLabelText, isActive: $showCameraPopover)
          .popover(isPresented: $showCameraPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
              CheckmarkRow(title: "None", isSelected: options?.selectedCamera == nil) {
                options?.selectedCamera = nil
                showCameraPopover = false
              }
              ForEach(availableCameras) { cam in
                CheckmarkRow(title: cam.name, isSelected: options?.selectedCamera?.id == cam.id) {
                  options?.selectedCamera = cam
                  showCameraPopover = false
                }
              }
            }
            .padding(.vertical, 8)
            .frame(width: 220)
            .background(ReframedColors.panelBackground)
          }
          .presentationBackground(ReframedColors.panelBackground)
      }
      .padding(.horizontal, 10)

      HStack {
        Text("Maximum Resolution")
          .font(.system(size: 13))
          .foregroundStyle(ReframedColors.primaryText)
        Spacer()
        SegmentPicker(
          items: ["720p", "1080p", "4K"],
          label: { $0 },
          isSelected: { cameraMaximumResolution == $0 },
          onSelect: {
            cameraMaximumResolution = $0
            ConfigService.shared.cameraMaximumResolution = $0
          }
        )
      }
      .padding(.horizontal, 10)
    }
  }
}
