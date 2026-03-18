import Foundation

enum SystemCursorType: Int, Codable, Sendable {
  case arrow = 0
  case iBeam = 1
  case pointingHand = 2
  case crosshair = 3
  case openHand = 4
  case closedHand = 5
  case resizeLeftRight = 6
  case resizeUpDown = 7
  case operationNotAllowed = 8
  case resizeUp = 9
  case resizeDown = 10
  case resizeLeft = 11
  case resizeRight = 12
  case disappearingItem = 13
  case contextMenu = 14
  case dragCopy = 15
  case dragLink = 16
  case iBeamHorizontal = 17
  case move = 18
  case busyButClickable = 19
  case cell = 20
  case help = 21
  case zoomIn = 22
  case zoomOut = 23
  case resizeNorth = 24
  case resizeSouth = 25
  case resizeEast = 26
  case resizeWest = 27
  case resizeNortheast = 28
  case resizeNorthwest = 29
  case resizeSoutheast = 30
  case resizeSouthwest = 31
  case resizeNorthSouth = 32
  case resizeEastWest = 33
  case resizeNortheastSouthwest = 34
  case resizeNorthwestSoutheast = 35
  case countingUpHand = 36
  case countingDownHand = 37
  case countingUpAndDownHand = 38
}

struct CursorSample: Codable, Sendable {
  let t: Double
  let x: Double
  let y: Double
  let p: Bool
  let c: Int?

  init(t: Double, x: Double, y: Double, p: Bool, c: Int? = nil) {
    self.t = t
    self.x = x
    self.y = y
    self.p = p
    self.c = c
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    t = try container.decode(Double.self, forKey: .t)
    x = try container.decode(Double.self, forKey: .x)
    y = try container.decode(Double.self, forKey: .y)
    p = try container.decode(Bool.self, forKey: .p)
    c = try container.decodeIfPresent(Int.self, forKey: .c)
  }

  enum CodingKeys: String, CodingKey {
    case t, x, y, p, c
  }
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
