import AVFoundation
import Combine
import Foundation
import Logging

@MainActor
@Observable
final class SyncedPlayerController {
  private let logger = Logger(label: "eu.jankuri.reframed.synced-player")
  let screenPlayer: AVPlayer
  let webcamPlayer: AVPlayer?
  private let systemAudioPlayer: AVPlayer?
  private(set) var currentTime: CMTime = .zero
  private(set) var duration: CMTime = .zero
  private(set) var isPlaying = false
  private var timeObserver: Any?
  private var boundaryObserver: Any?
  var trimEnd: CMTime = .zero
  var systemAudioRegions: [(start: CMTime, end: CMTime)] = []
  var micAudioRegions: [(start: CMTime, end: CMTime)] = []
  var videoRegions: [(start: Double, end: Double)] = []
  var previewMode = false
  var playbackSpeed: Double = 1.0 {
    didSet {
      guard playbackSpeed != oldValue else { return }
      applyAudioMutingForSpeed()
      if timeObserver != nil { setupTimeObserver() }
      if isPlaying { applyPlaybackRates() }
    }
  }

  private var micAudioEngine: AVAudioEngine?
  private var micPlayerNode: AVAudioPlayerNode?
  private var micAudioFile: AVAudioFile?
  private var micVolumeLevel: Float = 1.0
  private var micIsMutedByRegion: Bool = true
  private(set) var systemAudioDriftRatio: Double = 1.0
  private var webcamDriftRatio: Double = 1.0
  private(set) var micAudioDriftRatio: Double = 1.0

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
      setupMicEngine(url: micURL)
    }
  }

  private func setupMicEngine(url: URL) {
    let audioFile: AVAudioFile
    do {
      audioFile = try AVAudioFile(forReading: url)
    } catch {
      logger.error("Failed to open mic audio file: \(error)")
      return
    }
    micAudioFile = audioFile

    let engine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()

    engine.attach(playerNode)

    let format = audioFile.processingFormat
    engine.connect(playerNode, to: engine.mainMixerNode, format: format)

    do {
      try engine.start()
    } catch {
      logger.error("Failed to start audio engine: \(error)")
    }

    micAudioEngine = engine
    micPlayerNode = playerNode
  }

  func swapMicAudioFile(url: URL) {
    let wasPlaying = isPlaying
    let time = currentTime
    micPlayerNode?.stop()

    guard let engine = micAudioEngine, let playerNode = micPlayerNode else { return }

    engine.disconnectNodeOutput(playerNode)

    let audioFile: AVAudioFile
    do {
      audioFile = try AVAudioFile(forReading: url)
    } catch {
      logger.error("Failed to open swapped mic audio file: \(error)")
      return
    }
    micAudioFile = audioFile

    let format = audioFile.processingFormat
    engine.connect(playerNode, to: engine.mainMixerNode, format: format)

    if wasPlaying {
      scheduleMicPlayback(from: time)
    }
  }

  func loadDuration() async {
    guard let item = screenPlayer.currentItem else { return }
    do {
      duration = try await item.asset.load(.duration)
    } catch {
      logger.error("Failed to load duration: \(error)")
      duration = .zero
    }
    trimEnd = duration
  }

  func computeDriftRatios() async {
    let videoDuration = CMTimeGetSeconds(duration)
    guard videoDuration > 0 else { return }

    if let sysItem = systemAudioPlayer?.currentItem {
      if let sysDur = try? await sysItem.asset.load(.duration) {
        let audioSec = CMTimeGetSeconds(sysDur)
        if audioSec > 0 {
          let ratio = audioSec / videoDuration
          if abs(videoDuration - audioSec) > 0.01 {
            systemAudioDriftRatio = ratio
            logger.info(
              "System audio drift ratio: \(String(format: "%.6f", ratio)) (delta=\(String(format: "%.3f", videoDuration - audioSec))s)"
            )
          }
        }
      }
    }

    if let wcItem = webcamPlayer?.currentItem {
      if let wcDur = try? await wcItem.asset.load(.duration) {
        let wcSec = CMTimeGetSeconds(wcDur)
        if wcSec > 0 {
          let ratio = wcSec / videoDuration
          if abs(videoDuration - wcSec) > 0.01 {
            webcamDriftRatio = ratio
            logger.info("Webcam drift ratio: \(String(format: "%.6f", ratio)) (delta=\(String(format: "%.3f", videoDuration - wcSec))s)")
          }
        }
      }
    }

    if let micFile = micAudioFile {
      let micSec = Double(micFile.length) / micFile.processingFormat.sampleRate
      if micSec > 0 {
        let ratio = micSec / videoDuration
        if abs(videoDuration - micSec) > 0.01 {
          micAudioDriftRatio = ratio
          logger.info("Mic audio drift ratio: \(String(format: "%.6f", ratio)) (delta=\(String(format: "%.3f", videoDuration - micSec))s)")
        }
      }
    }
  }

  private var dropsAudioForSpeed: Bool { TimeLapse.dropsAudio(speed: playbackSpeed) }

  private func applyPlaybackRates() {
    let speed = TimeLapse.clamp(playbackSpeed)
    screenPlayer.rate = Float(speed)
    webcamPlayer?.rate = Float(webcamDriftRatio * speed)
    systemAudioPlayer?.rate = Float(systemAudioDriftRatio * speed)
  }

  private func applyAudioMutingForSpeed() {
    if dropsAudioForSpeed {
      systemAudioPlayer?.isMuted = true
      micPlayerNode?.volume = 0
    }
  }

  func setupTimeObserver() {
    if let obs = timeObserver {
      screenPlayer.removeTimeObserver(obs)
      timeObserver = nil
    }
    let interval = CMTime(value: CMTimeValue(max(1, Int(TimeLapse.clamp(playbackSpeed)))), timescale: 60)
    timeObserver = screenPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
      [weak self] time in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.currentTime = time
        if self.trimEnd.isValid && CMTimeCompare(time, self.trimEnd) >= 0 {
          self.pause()
        }
        if self.previewMode && self.isPlaying {
          self.handlePreviewGapSkip(at: CMTimeGetSeconds(time))
        }
        self.updateAudioMuting(at: time)
      }
    }
  }

  private func handlePreviewGapSkip(at time: Double) {
    let regions = videoRegions
    guard !regions.isEmpty else { return }
    let inRegion = regions.contains { time >= $0.start && time < $0.end }
    if !inRegion {
      if let next = regions.first(where: { $0.start > time }) {
        let seekTime = CMTime(seconds: next.start, preferredTimescale: 600)
        seek(to: seekTime)
        applyPlaybackRates()
        scheduleMicPlayback(from: seekTime)
      } else {
        pause()
      }
    }
  }

  private func updateAudioMuting(at time: CMTime) {
    if let sysPlayer = systemAudioPlayer {
      let inRange = systemAudioRegions.contains { region in
        CMTimeCompare(time, region.start) >= 0 && CMTimeCompare(time, region.end) < 0
      }
      sysPlayer.isMuted = !inRange || dropsAudioForSpeed
    }
    if micPlayerNode != nil {
      let inRange = micAudioRegions.contains { region in
        CMTimeCompare(time, region.start) >= 0 && CMTimeCompare(time, region.end) < 0
      }
      micIsMutedByRegion = !inRange
      micPlayerNode?.volume = (micIsMutedByRegion || dropsAudioForSpeed) ? 0 : micVolumeLevel
    }
  }

  func play() {
    guard !isPlaying else { return }
    if trimEnd.isValid && CMTimeCompare(currentTime, trimEnd) >= 0 {
      return
    }
    applyPlaybackRates()
    scheduleMicPlayback(from: currentTime)
    applyAudioMutingForSpeed()
    isPlaying = true
  }

  func pause() {
    screenPlayer.pause()
    webcamPlayer?.pause()
    systemAudioPlayer?.pause()
    micPlayerNode?.stop()
    isPlaying = false
    syncAuxPlayers()
  }

  func seek(to time: CMTime) {
    let toleranceBefore = CMTime(value: 1, timescale: 600)
    let toleranceAfter = CMTime(value: 1, timescale: 600)
    screenPlayer.seek(to: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter)
    let wcTime = CMTimeMultiplyByFloat64(time, multiplier: webcamDriftRatio)
    webcamPlayer?.seek(to: wcTime, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter)
    let sysTime = CMTimeMultiplyByFloat64(time, multiplier: systemAudioDriftRatio)
    systemAudioPlayer?.seek(to: sysTime, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter)
    micPlayerNode?.stop()
    currentTime = time
  }

  func setSystemAudioVolume(_ volume: Float) {
    systemAudioPlayer?.volume = volume
  }

  func setMicAudioVolume(_ volume: Float) {
    micVolumeLevel = volume
    if !micIsMutedByRegion {
      micPlayerNode?.volume = volume
    }
  }

  func teardown() {
    if let obs = timeObserver {
      screenPlayer.removeTimeObserver(obs)
      timeObserver = nil
    }
    screenPlayer.pause()
    webcamPlayer?.pause()
    systemAudioPlayer?.pause()
    if let engine = micAudioEngine {
      micPlayerNode?.stop()
      engine.stop()
      if let node = micPlayerNode { engine.detach(node) }
      engine.reset()
    }
    micPlayerNode = nil
    micAudioEngine = nil
    micAudioFile = nil
  }

  private func scheduleMicPlayback(from time: CMTime) {
    guard let playerNode = micPlayerNode, let audioFile = micAudioFile else { return }
    playerNode.stop()
    let sampleRate = audioFile.processingFormat.sampleRate
    let audioTime = CMTimeGetSeconds(time) * micAudioDriftRatio
    let startFrame = AVAudioFramePosition(audioTime * sampleRate)
    let totalFrames = AVAudioFramePosition(audioFile.length)
    guard startFrame < totalFrames else { return }
    let frameCount = AVAudioFrameCount(totalFrames - startFrame)
    playerNode.scheduleSegment(
      audioFile,
      startingFrame: startFrame,
      frameCount: frameCount,
      at: nil
    )
    playerNode.play()
  }

  private func syncAuxPlayers() {
    let screenTime = screenPlayer.currentTime()
    let tolerance = CMTime(value: 1, timescale: 600)
    let wcTime = CMTimeMultiplyByFloat64(screenTime, multiplier: webcamDriftRatio)
    webcamPlayer?.seek(to: wcTime, toleranceBefore: tolerance, toleranceAfter: tolerance)
    let sysTime = CMTimeMultiplyByFloat64(screenTime, multiplier: systemAudioDriftRatio)
    systemAudioPlayer?.seek(to: sysTime, toleranceBefore: tolerance, toleranceAfter: tolerance)
  }
}
