import Foundation

struct CursorSample: Codable, Sendable {
  let t: Double
  let x: Double
  let y: Double
  let p: Bool
}

struct CursorClickEvent: Codable, Sendable {
  let t: Double
  let x: Double
  let y: Double
  let button: Int
}

struct KeystrokeEvent: Codable, Sendable {
  let t: Double
  let keyCode: UInt16
  let modifiers: UInt
  let isDown: Bool
}

struct CursorMetadataFile: Codable, Sendable {
  let version: Int
  let captureAreaWidth: Double
  let captureAreaHeight: Double
  let displayScale: Double
  let sampleRateHz: Int
  var samples: [CursorSample]
  var clicks: [CursorClickEvent]
  var keystrokes: [KeystrokeEvent]

  init(
    captureAreaWidth: Double,
    captureAreaHeight: Double,
    displayScale: Double,
    sampleRateHz: Int = 120,
    samples: [CursorSample] = [],
    clicks: [CursorClickEvent] = [],
    keystrokes: [KeystrokeEvent] = []
  ) {
    self.version = 1
    self.captureAreaWidth = captureAreaWidth
    self.captureAreaHeight = captureAreaHeight
    self.displayScale = displayScale
    self.sampleRateHz = sampleRateHz
    self.samples = samples
    self.clicks = clicks
    self.keystrokes = keystrokes
  }
}
