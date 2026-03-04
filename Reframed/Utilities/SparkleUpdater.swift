import Combine
import Sparkle
import SwiftUI

@MainActor
@Observable
final class SparkleUpdater {
  private let controller: SPUStandardUpdaterController
  private var cancellable: AnyCancellable?

  @ObservationIgnored
  private(set) var canCheckForUpdates = false

  init() {
    controller = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )
    cancellable = controller.updater.publisher(for: \.canCheckForUpdates)
      .sink { [weak self] value in
        self?.canCheckForUpdates = value
      }
  }

  func checkForUpdates() {
    controller.checkForUpdates(nil)
  }
}
