import CoreMedia
import Logging

final class SharedRecordingClock: @unchecked Sendable {
  private let lock = NSLock()
  private var _referenceTime: CMTime = .invalid
  private var firstPTSValues: [CMTime] = []
  private let streamCount: Int
  private let logger = Logger(label: "eu.jankuri.reframed.recording-clock")

  init(streamCount: Int) {
    self.streamCount = streamCount
  }

  func registerStream(firstPTS: CMTime) {
    lock.lock()
    defer { lock.unlock() }
    guard firstPTSValues.count < streamCount else { return }
    firstPTSValues.append(firstPTS)
    if firstPTSValues.count >= streamCount {
      _referenceTime = firstPTSValues.max(by: { CMTimeCompare($0, $1) < 0 })!
      logger.info("Reference time set: \(String(format: "%.3f", CMTimeGetSeconds(_referenceTime)))s from \(streamCount) streams")
    }
  }

  var referenceTimeSeconds: Double? {
    lock.lock()
    let ref = _referenceTime
    lock.unlock()
    guard ref.isValid else { return nil }
    return CMTimeGetSeconds(ref)
  }

  func adjustPTS(_ rawPTS: CMTime, pauseOffset: CMTime) -> CMTime? {
    lock.lock()
    let ref = _referenceTime
    lock.unlock()
    guard ref.isValid else { return nil }
    let adjusted = CMTimeSubtract(CMTimeSubtract(rawPTS, ref), pauseOffset)
    guard CMTimeCompare(adjusted, .zero) >= 0 else { return nil }
    return adjusted
  }
}
