import SwiftUI

extension SettingsView {
  var devicesContent: some View {
    Group {
      settingsToggle(
        "Capture System Audio",
        isOn: Binding(
          get: { options?.captureSystemAudio ?? false },
          set: { options?.captureSystemAudio = $0 }
        )
      )

      settingsRow(label: "Microphone") {
        SelectButton(label: microphoneLabel) {
          VStack(alignment: .leading, spacing: 0) {
            CheckmarkRow(title: "None", isSelected: options?.selectedMicrophone == nil) {
              options?.selectedMicrophone = nil
            }
            ForEach(availableMicrophones) { mic in
              CheckmarkRow(title: mic.name, isSelected: options?.selectedMicrophone?.id == mic.id) {
                options?.selectedMicrophone = mic
              }
            }
          }
          .padding(.vertical, 8)
          .frame(width: 320)
        }
      }

      settingsRow(label: "Camera Device") {
        SelectButton(label: cameraLabelText) {
          VStack(alignment: .leading, spacing: 0) {
            CheckmarkRow(title: "None", isSelected: options?.selectedCamera == nil) {
              options?.selectedCamera = nil
            }
            ForEach(availableCameras) { cam in
              CheckmarkRow(title: cam.name, isSelected: options?.selectedCamera?.id == cam.id) {
                options?.selectedCamera = cam
              }
            }
          }
          .padding(.vertical, 8)
          .frame(width: 320)
        }
      }

      settingsRow(label: "Maximum Camera Resolution") {
        FullWidthSegmentPicker(
          items: ["720p", "1080p", "4K"],
          label: { $0 },
          selection: Binding(
            get: { cameraMaximumResolution },
            set: {
              cameraMaximumResolution = $0
              ConfigService.shared.cameraMaximumResolution = $0
            }
          )
        )
      }
    }
  }

  var microphoneLabel: String {
    guard let id = options?.selectedMicrophone?.id else { return "None" }
    return availableMicrophones.first { $0.id == id }?.name ?? "None"
  }

  var cameraLabelText: String {
    guard let id = options?.selectedCamera?.id else { return "None" }
    return availableCameras.first { $0.id == id }?.name ?? "None"
  }
}
