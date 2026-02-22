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
  var videoRegions: [(start: Double, end: Double)] = []
  var previewMode = false

  private var micAudioEngine: AVAudioEngine?
  private var micPlayerNode: AVAudioPlayerNode?
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

    engine.attach(playerNode)

    let format = audioFile.processingFormat
    engine.connect(playerNode, to: engine.mainMixerNode, format: format)

    try? engine.start()

    micAudioEngine = engine
    micPlayerNode = playerNode
  }

  func swapMicAudioFile(url: URL) {
    let wasPlaying = isPlaying
    let time = currentTime
    micPlayerNode?.stop()

    guard let engine = micAudioEngine, let playerNode = micPlayerNode else { return }

    engine.disconnectNodeOutput(playerNode)

    guard let audioFile = try? AVAudioFile(forReading: url) else { return }
    micAudioFile = audioFile

    let format = audioFile.processingFormat
    engine.connect(playerNode, to: engine.mainMixerNode, format: format)

    if wasPlaying {
      scheduleMicPlayback(from: time)
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
        screenPlayer.play()
        webcamPlayer?.play()
        systemAudioPlayer?.play()
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
