import AVFoundation
import Combine
import Foundation

@MainActor
@Observable
final class SyncedPlayerController {
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

  private var micAudioEngine: AVAudioEngine?
  private var micPlayerNode: AVAudioPlayerNode?
  private var micEQ: AVAudioUnitEQ?
  private var micAudioFile: AVAudioFile?
  private var micVolumeLevel: Float = 1.0
  private var micIsMutedByRegion: Bool = true

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
    guard let audioFile = try? AVAudioFile(forReading: url) else { return }
    micAudioFile = audioFile

    let engine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()
    let eq = AVAudioUnitEQ(numberOfBands: 2)

    let highPass = eq.bands[0]
    highPass.filterType = .highPass
    highPass.frequency = 80
    highPass.bandwidth = 1.0
    highPass.bypass = true

    let lowPass = eq.bands[1]
    lowPass.filterType = .lowPass
    lowPass.frequency = 20000
    lowPass.bandwidth = 1.0
    lowPass.bypass = true

    engine.attach(playerNode)
    engine.attach(eq)

    let format = audioFile.processingFormat
    engine.connect(playerNode, to: eq, format: format)
    engine.connect(eq, to: engine.mainMixerNode, format: format)

    try? engine.start()

    micAudioEngine = engine
    micPlayerNode = playerNode
    micEQ = eq
  }

  func loadDuration() async {
    guard let item = screenPlayer.currentItem else { return }
    let d = try? await item.asset.load(.duration)
    duration = d ?? .zero
    trimEnd = duration
  }

  func setupTimeObserver() {
    let interval = CMTime(value: 1, timescale: 30)
    timeObserver = screenPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
      [weak self] time in
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
      let inRange = systemAudioRegions.contains { region in
        CMTimeCompare(time, region.start) >= 0 && CMTimeCompare(time, region.end) < 0
      }
      sysPlayer.isMuted = !inRange
    }
    if micPlayerNode != nil {
      let inRange = micAudioRegions.contains { region in
        CMTimeCompare(time, region.start) >= 0 && CMTimeCompare(time, region.end) < 0
      }
      micIsMutedByRegion = !inRange
      micPlayerNode?.volume = micIsMutedByRegion ? 0 : micVolumeLevel
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
    scheduleMicPlayback(from: currentTime)
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
    webcamPlayer?.seek(to: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter)
    systemAudioPlayer?.seek(to: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter)
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

  func setMicNoiseReduction(enabled: Bool, intensity: Float) {
    guard let eq = micEQ else { return }
    let highPass = eq.bands[0]
    let lowPass = eq.bands[1]
    highPass.bypass = !enabled
    lowPass.bypass = !enabled
    if enabled {
      highPass.frequency = 80 + (300 - 80) * intensity
      lowPass.frequency = 20000 - (20000 - 8000) * intensity
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
      if let eq = micEQ { engine.detach(eq) }
      engine.reset()
    }
    micPlayerNode = nil
    micEQ = nil
    micAudioEngine = nil
    micAudioFile = nil
  }

  private func scheduleMicPlayback(from time: CMTime) {
    guard let playerNode = micPlayerNode, let audioFile = micAudioFile else { return }
    playerNode.stop()
    let sampleRate = audioFile.processingFormat.sampleRate
    let startFrame = AVAudioFramePosition(CMTimeGetSeconds(time) * sampleRate)
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
    webcamPlayer?.seek(to: screenTime, toleranceBefore: tolerance, toleranceAfter: tolerance)
    systemAudioPlayer?.seek(to: screenTime, toleranceBefore: tolerance, toleranceAfter: tolerance)
  }
}
