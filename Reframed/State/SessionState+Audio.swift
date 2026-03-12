import AppKit
import Foundation

@MainActor
extension SessionState {
  func toggleMicrophone() {
    guard options.selectedMicrophone != nil else { return }
    isMicrophoneOn.toggle()
    ConfigService.shared.isMicrophoneOn = isMicrophoneOn
  }

  func startAudioLevelPolling() {
    audioLevelTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self, let coordinator = self.recordingCoordinator else { break }
        let levels = await coordinator.getAudioLevels()
        self.micAudioLevel = levels.mic
        self.systemAudioLevel = levels.system
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
  }

  func stopAudioLevelPolling() {
    audioLevelTask?.cancel()
    audioLevelTask = nil
    micAudioLevel = 0
    systemAudioLevel = 0
  }
}
