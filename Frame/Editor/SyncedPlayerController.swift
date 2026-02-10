import AVFoundation
import Combine
import Foundation

@MainActor
@Observable
final class SyncedPlayerController {
  let screenPlayer: AVPlayer
  let webcamPlayer: AVPlayer?
  private(set) var currentTime: CMTime = .zero
  private(set) var duration: CMTime = .zero
  private(set) var isPlaying = false
  private var timeObserver: Any?
  private var boundaryObserver: Any?
  var trimEnd: CMTime = .zero

  init(result: RecordingResult) {
    let screenAsset = AVURLAsset(url: result.screenVideoURL)
    screenPlayer = AVPlayer(playerItem: AVPlayerItem(asset: screenAsset))
    screenPlayer.actionAtItemEnd = .pause

    if let webcamURL = result.webcamVideoURL {
      let webcamAsset = AVURLAsset(url: webcamURL)
      webcamPlayer = AVPlayer(playerItem: AVPlayerItem(asset: webcamAsset))
      webcamPlayer?.actionAtItemEnd = .pause
    } else {
      webcamPlayer = nil
    }
  }

  func loadDuration() async {
    guard let item = screenPlayer.currentItem else { return }
    let d = try? await item.asset.load(.duration)
    duration = d ?? .zero
    trimEnd = duration
  }

  func setupTimeObserver() {
    let interval = CMTime(value: 1, timescale: 30)
    timeObserver = screenPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.currentTime = time
        if self.trimEnd.isValid && CMTimeCompare(time, self.trimEnd) >= 0 {
          self.pause()
        }
      }
    }
  }

  func play() {
    guard !isPlaying else { return }
    if trimEnd.isValid && CMTimeCompare(currentTime, trimEnd) >= 0 {
      return
    }
    screenPlayer.play()
    webcamPlayer?.play()
    isPlaying = true
  }

  func pause() {
    screenPlayer.pause()
    webcamPlayer?.pause()
    isPlaying = false
    syncWebcam()
  }

  func seek(to time: CMTime) {
    let toleranceBefore = CMTime(value: 1, timescale: 600)
    let toleranceAfter = CMTime(value: 1, timescale: 600)
    screenPlayer.seek(to: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter)
    webcamPlayer?.seek(to: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter)
    currentTime = time
  }

  func teardown() {
    if let obs = timeObserver {
      screenPlayer.removeTimeObserver(obs)
      timeObserver = nil
    }
    screenPlayer.pause()
    webcamPlayer?.pause()
  }

  private func syncWebcam() {
    guard let webcam = webcamPlayer else { return }
    let screenTime = screenPlayer.currentTime()
    let tolerance = CMTime(value: 1, timescale: 600)
    webcam.seek(to: screenTime, toleranceBefore: tolerance, toleranceAfter: tolerance)
  }
}
