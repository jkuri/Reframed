import AVFoundation
import Combine
import Foundation

@MainActor
@Observable
final class SyncedPlayerController {
  let screenPlayer: AVPlayer
  let webcamPlayer: AVPlayer?
  private let systemAudioPlayer: AVPlayer?
  private let micAudioPlayer: AVPlayer?
  private(set) var currentTime: CMTime = .zero
  private(set) var duration: CMTime = .zero
  private(set) var isPlaying = false
  private var timeObserver: Any?
  private var boundaryObserver: Any?
  var trimEnd: CMTime = .zero
  var systemAudioTrimStart: CMTime = .zero
  var systemAudioTrimEnd: CMTime = .zero
  var micAudioTrimStart: CMTime = .zero
  var micAudioTrimEnd: CMTime = .zero

  init(result: RecordingResult) {
    let screenAsset = AVURLAsset(url: result.screenVideoURL)
    screenPlayer = AVPlayer(playerItem: AVPlayerItem(asset: screenAsset))
    screenPlayer.actionAtItemEnd = .pause

    if let webcamURL = result.webcamVideoURL {
      let webcamAsset = AVURLAsset(url: webcamURL)
      webcamPlayer = AVPlayer(playerItem: AVPlayerItem(asset: webcamAsset))
      webcamPlayer?.actionAtItemEnd = .pause
      webcamPlayer?.isMuted = true
    } else {
      webcamPlayer = nil
    }

    let hasExternalAudio = result.systemAudioURL != nil || result.microphoneAudioURL != nil
    if hasExternalAudio {
      screenPlayer.isMuted = true
    }

    if let sysURL = result.systemAudioURL {
      systemAudioPlayer = AVPlayer(playerItem: AVPlayerItem(asset: AVURLAsset(url: sysURL)))
      systemAudioPlayer?.actionAtItemEnd = .pause
    } else {
      systemAudioPlayer = nil
    }

    if let micURL = result.microphoneAudioURL {
      micAudioPlayer = AVPlayer(playerItem: AVPlayerItem(asset: AVURLAsset(url: micURL)))
      micAudioPlayer?.actionAtItemEnd = .pause
    } else {
      micAudioPlayer = nil
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
        self.updateAudioMuting(at: time)
      }
    }
  }

  private func updateAudioMuting(at time: CMTime) {
    if let sysPlayer = systemAudioPlayer {
      let inRange = CMTimeCompare(time, systemAudioTrimStart) >= 0 && CMTimeCompare(time, systemAudioTrimEnd) < 0
      sysPlayer.isMuted = !inRange
    }
    if let micPlayer = micAudioPlayer {
      let inRange = CMTimeCompare(time, micAudioTrimStart) >= 0 && CMTimeCompare(time, micAudioTrimEnd) < 0
      micPlayer.isMuted = !inRange
    }
  }

  func play() {
    guard !isPlaying else { return }
    if trimEnd.isValid && CMTimeCompare(currentTime, trimEnd) >= 0 {
      return
    }
    screenPlayer.play()
    webcamPlayer?.play()
    systemAudioPlayer?.play()
    micAudioPlayer?.play()
    isPlaying = true
  }

  func pause() {
    screenPlayer.pause()
    webcamPlayer?.pause()
    systemAudioPlayer?.pause()
    micAudioPlayer?.pause()
    isPlaying = false
    syncAuxPlayers()
  }

  func seek(to time: CMTime) {
    let toleranceBefore = CMTime(value: 1, timescale: 600)
    let toleranceAfter = CMTime(value: 1, timescale: 600)
    screenPlayer.seek(to: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter)
    webcamPlayer?.seek(to: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter)
    systemAudioPlayer?.seek(to: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter)
    micAudioPlayer?.seek(to: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter)
    currentTime = time
  }

  func teardown() {
    if let obs = timeObserver {
      screenPlayer.removeTimeObserver(obs)
      timeObserver = nil
    }
    screenPlayer.pause()
    webcamPlayer?.pause()
    systemAudioPlayer?.pause()
    micAudioPlayer?.pause()
  }

  private func syncAuxPlayers() {
    let screenTime = screenPlayer.currentTime()
    let tolerance = CMTime(value: 1, timescale: 600)
    webcamPlayer?.seek(to: screenTime, toleranceBefore: tolerance, toleranceAfter: tolerance)
    systemAudioPlayer?.seek(to: screenTime, toleranceBefore: tolerance, toleranceAfter: tolerance)
    micAudioPlayer?.seek(to: screenTime, toleranceBefore: tolerance, toleranceAfter: tolerance)
  }
}
