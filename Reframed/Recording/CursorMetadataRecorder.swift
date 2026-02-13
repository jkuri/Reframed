import AppKit
import CoreMedia
import Foundation

final class CursorMetadataRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var timer: DispatchSourceTimer?
  private let queue = DispatchQueue(label: "eu.jankuri.reframed.cursor-metadata", qos: .userInteractive)

  private var captureOriginX: Double = 0
  private var captureOriginY: Double = 0
  private var captureWidth: Double = 0
  private var captureHeight: Double = 0
  private var displayScale: Double = 2.0
  private var displayHeight: Double = 0
  private var isConfigured = false

  private var samples: [CursorSample] = []
  private var clicks: [CursorClickEvent] = []
  private var keystrokes: [KeystrokeEvent] = []

  private var startHostTime: CMTime = .invalid
  private var isPaused = false
  private var totalPauseOffset: Double = 0
  private var pauseStartHostTime: Double = 0

  func configure(
    captureOrigin: CGPoint,
    captureSize: CGSize,
    displayScale: CGFloat,
    displayHeight: CGFloat
  ) {
    lock.lock()
    self.captureOriginX = Double(captureOrigin.x)
    self.captureOriginY = Double(captureOrigin.y)
    self.captureWidth = Double(captureSize.width)
    self.captureHeight = Double(captureSize.height)
    self.displayScale = Double(displayScale)
    self.displayHeight = Double(displayHeight)
    self.isConfigured = true
    lock.unlock()
  }

  func start() {
    lock.lock()
    startHostTime = CMClockGetTime(CMClockGetHostTimeClock())
    isPaused = false
    totalPauseOffset = 0
    lock.unlock()

    let source = DispatchSource.makeTimerSource(queue: queue)
    source.schedule(deadline: .now(), repeating: .milliseconds(8))
    source.setEventHandler { [weak self] in
      self?.sampleCursor()
    }
    source.resume()

    lock.lock()
    timer = source
    lock.unlock()
  }

  func pause() {
    lock.lock()
    isPaused = true
    pauseStartHostTime = CMTimeGetSeconds(CMClockGetTime(CMClockGetHostTimeClock()))
    lock.unlock()
  }

  func resume() {
    lock.lock()
    if isPaused {
      let now = CMTimeGetSeconds(CMClockGetTime(CMClockGetHostTimeClock()))
      totalPauseOffset += now - pauseStartHostTime
    }
    isPaused = false
    lock.unlock()
  }

  func recordClick(at screenPoint: CGPoint, button: Int) {
    lock.lock()
    guard isConfigured, !isPaused, startHostTime.isValid else {
      lock.unlock()
      return
    }
    let t = adjustedTime()
    let (nx, ny) = normalizePoint(screenX: Double(screenPoint.x), screenY: Double(screenPoint.y))
    guard nx >= -0.1 && nx <= 1.1 && ny >= -0.1 && ny <= 1.1 else {
      lock.unlock()
      return
    }
    clicks.append(CursorClickEvent(t: t, x: nx, y: ny, button: button))
    lock.unlock()
  }

  func recordKeystroke(keyCode: UInt16, modifiers: UInt, isDown: Bool) {
    lock.lock()
    guard isConfigured, !isPaused, startHostTime.isValid else {
      lock.unlock()
      return
    }
    let t = adjustedTime()
    keystrokes.append(KeystrokeEvent(t: t, keyCode: keyCode, modifiers: modifiers, isDown: isDown))
    lock.unlock()
  }

  var startHostTimeSeconds: Double {
    lock.lock()
    let t = startHostTime.isValid ? CMTimeGetSeconds(startHostTime) : 0
    lock.unlock()
    return t
  }

  func stop() {
    lock.lock()
    timer?.cancel()
    timer = nil
    lock.unlock()
  }

  func adjustTimestamps(by offset: Double) {
    lock.lock()
    for i in samples.indices {
      let s = samples[i]
      samples[i] = CursorSample(t: s.t + offset, x: s.x, y: s.y, p: s.p)
    }
    for i in clicks.indices {
      let c = clicks[i]
      clicks[i] = CursorClickEvent(t: c.t + offset, x: c.x, y: c.y, button: c.button)
    }
    for i in keystrokes.indices {
      let k = keystrokes[i]
      keystrokes[i] = KeystrokeEvent(t: k.t + offset, keyCode: k.keyCode, modifiers: k.modifiers, isDown: k.isDown)
    }
    lock.unlock()
  }

  func buildMetadataFile() -> CursorMetadataFile {
    lock.lock()
    let file = CursorMetadataFile(
      captureAreaWidth: captureWidth,
      captureAreaHeight: captureHeight,
      displayScale: displayScale,
      sampleRateHz: 120,
      samples: samples,
      clicks: clicks,
      keystrokes: keystrokes
    )
    lock.unlock()
    return file
  }

  func writeToFile(at url: URL) throws {
    let file = buildMetadataFile()
    let encoder = JSONEncoder()
    let data = try encoder.encode(file)
    try data.write(to: url)
  }

  private func sampleCursor() {
    lock.lock()
    guard isConfigured, !isPaused, startHostTime.isValid else {
      lock.unlock()
      return
    }

    let t = adjustedTime()
    let captOriginX = captureOriginX
    let captOriginY = captureOriginY
    let captW = captureWidth
    let captH = captureHeight
    let dispH = displayHeight
    lock.unlock()

    let mouseLocation = NSEvent.mouseLocation
    let pressed = NSEvent.pressedMouseButtons != 0
    let mouseX = Double(mouseLocation.x)
    let mouseY = Double(mouseLocation.y)

    let sckY = dispH - mouseY
    let nx = (mouseX - captOriginX) / captW
    let ny = (sckY - captOriginY) / captH

    let sample = CursorSample(t: t, x: nx, y: ny, p: pressed)

    lock.lock()
    samples.append(sample)
    lock.unlock()
  }

  private func adjustedTime() -> Double {
    let now = CMTimeGetSeconds(CMClockGetTime(CMClockGetHostTimeClock()))
    let start = CMTimeGetSeconds(startHostTime)
    return now - start - totalPauseOffset
  }

  private func normalizePoint(screenX: Double, screenY: Double) -> (Double, Double) {
    let sckY = displayHeight - screenY
    let nx = (screenX - captureOriginX) / captureWidth
    let ny = (sckY - captureOriginY) / captureHeight
    return (nx, ny)
  }
}
