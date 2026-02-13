import SwiftUI

struct OptionsPopover: View {
  @Bindable var options: RecordingOptions

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SectionHeader(title: "Timer")

      ForEach(TimerDelay.allCases, id: \.self) { delay in
        CheckmarkRow(
          title: delay.label,
          isSelected: options.timerDelay == delay
        ) {
          options.timerDelay = delay
        }
      }

      Divider()
        .background(ReframedColors.divider)
        .padding(.vertical, 4)

      SectionHeader(title: "Audio")

      CheckmarkRow(
        title: "Capture System Audio",
        isSelected: options.captureSystemAudio
      ) {
        options.captureSystemAudio.toggle()
      }

      Divider()
        .background(ReframedColors.divider)
        .padding(.vertical, 4)

      SectionHeader(title: "Microphone")

      CheckmarkRow(
        title: "None",
        isSelected: options.selectedMicrophone == nil
      ) {
        options.selectedMicrophone = nil
      }

      ForEach(options.availableMicrophones) { mic in
        CheckmarkRow(
          title: mic.name,
          isSelected: options.selectedMicrophone?.id == mic.id
        ) {
          options.selectedMicrophone = mic
        }
      }

      Divider()
        .background(ReframedColors.divider)
        .padding(.vertical, 4)

      SectionHeader(title: "Camera")

      CheckmarkRow(
        title: "None",
        isSelected: options.selectedCamera == nil
      ) {
        options.selectedCamera = nil
      }

      ForEach(options.availableCameras) { cam in
        CheckmarkRow(
          title: cam.name,
          isSelected: options.selectedCamera?.id == cam.id
        ) {
          options.selectedCamera = cam
        }
      }

      Divider()
        .background(ReframedColors.divider)
        .padding(.vertical, 4)

      SectionHeader(title: "Options")

      CheckmarkRow(
        title: "Remember Last Selection",
        isSelected: options.rememberLastSelection
      ) {
        options.rememberLastSelection.toggle()
      }
    }
    .padding(.vertical, 8)
    .frame(width: 220)
    .background(ReframedColors.panelBackground)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .strokeBorder(ReframedColors.subtleBorder, lineWidth: 0.5)
    )
  }
}
