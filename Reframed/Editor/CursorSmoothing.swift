import CoreGraphics
import Foundation

enum CursorMovementSpeed: String, Codable, Sendable, CaseIterable, Identifiable {
  case slow
  case medium
  case fast
  case rapid

  var id: String { rawValue }

  var label: String {
    switch self {
    case .slow: "Slow"
    case .medium: "Medium"
    case .fast: "Fast"
    case .rapid: "Rapid"
    }
  }

  var tension: Double {
    switch self {
    case .slow: 80
    case .medium: 170
    case .fast: 300
    case .rapid: 500
    }
  }

  var friction: Double {
    switch self {
    case .slow: 20
    case .medium: 26
    case .fast: 34
    case .rapid: 44
    }
  }

  var mass: Double {
    switch self {
    case .slow: 3.0
    case .medium: 1.5
    case .fast: 1.0
    case .rapid: 0.6
    }
  }

  var convergenceDuration: Double {
    switch self {
    case .slow: 0.3
    case .medium: 0.2
    case .fast: 0.15
    case .rapid: 0.1
    }
  }
}

enum CursorSmoothing {
  static func smooth(
    samples: [CursorSample],
    speed: CursorMovementSpeed,
    clicks: [CursorClickEvent] = [],
    zoomTimeline: ZoomTimeline? = nil,
    keystrokes: [KeystrokeEvent] = []
  ) -> [CursorSample] {
    guard samples.count >= 2 else { return samples }

    let tension = speed.tension
    let friction = speed.friction
    let mass = speed.mass
    let convergence = speed.convergenceDuration
    let sortedClicks = clicks.sorted { $0.t < $1.t }
    var clickIdx = 0

    let typingIntervals = buildTypingIntervals(from: keystrokes)

    var result: [CursorSample] = []
    result.reserveCapacity(samples.count)

    var posX = samples[0].x
    var posY = samples[0].y
    var velX = 0.0
    var velY = 0.0

    result.append(CursorSample(t: samples[0].t, x: posX, y: posY, p: samples[0].p, c: samples[0].c))

    for i in 1..<samples.count {
      let target = samples[i]
      let prev = samples[i - 1]
      let dt = target.t - prev.t
      guard dt > 0 && dt < 1.0 else {
        posX = target.x
        posY = target.y
        velX = 0
        velY = 0
        result.append(CursorSample(t: target.t, x: posX, y: posY, p: target.p, c: target.c))
        while clickIdx < sortedClicks.count && sortedClicks[clickIdx].t <= target.t {
          clickIdx += 1
        }
        continue
      }

      let zoomScale = zoomScaleFactor(at: target.t, timeline: zoomTimeline)
      let isTyping = isInTypingInterval(target.t, intervals: typingIntervals)

      var effectiveTension = tension
      var effectiveFriction = friction
      var effectiveMass = mass

      if zoomScale > 1.05 {
        let boost = min(zoomScale, 4.0)
        effectiveTension *= boost
        effectiveFriction *= boost * 0.8
        effectiveMass *= 0.7
      }

      if isTyping {
        effectiveTension *= 2.0
        effectiveFriction *= 1.5
      }

      let steps = max(1, Int(ceil(dt / 0.001)))
      let stepDt = dt / Double(steps)

      for _ in 0..<steps {
        let accelX = (effectiveTension * (target.x - posX) - effectiveFriction * velX) / effectiveMass
        let accelY = (effectiveTension * (target.y - posY) - effectiveFriction * velY) / effectiveMass
        velX += accelX * stepDt
        velY += accelY * stepDt
        posX += velX * stepDt
        posY += velY * stepDt
      }

      while clickIdx < sortedClicks.count && sortedClicks[clickIdx].t <= prev.t {
        clickIdx += 1
      }

      if clickIdx < sortedClicks.count {
        let click = sortedClicks[clickIdx]
        if click.t > prev.t && click.t <= target.t {
          posX = click.x
          posY = click.y
          velX = 0
          velY = 0
          result.append(CursorSample(t: target.t, x: posX, y: posY, p: target.p, c: target.c))
          clickIdx += 1
          continue
        }
      }

      var outX = posX
      var outY = posY

      if clickIdx < sortedClicks.count {
        let click = sortedClicks[clickIdx]
        let timeToClick = click.t - target.t
        let effectiveConvergence = zoomScale > 1.05 ? convergence * 1.5 : convergence
        if timeToClick > 0 && timeToClick <= effectiveConvergence {
          let raw = 1.0 - timeToClick / effectiveConvergence
          let blend = raw * raw * (3.0 - 2.0 * raw)
          outX = posX + (click.x - posX) * blend
          outY = posY + (click.y - posY) * blend
        }
      }

      result.append(CursorSample(t: target.t, x: outX, y: outY, p: target.p, c: target.c))
    }

    return result
  }

  private static func zoomScaleFactor(at time: Double, timeline: ZoomTimeline?) -> Double {
    guard let timeline else { return 1.0 }
    let rect = timeline.zoomRect(at: time)
    guard rect.width > 0 && rect.width < 1.0 else { return 1.0 }
    return 1.0 / rect.width
  }

  private struct TimeInterval {
    let start: Double
    let end: Double
  }

  private static func buildTypingIntervals(from keystrokes: [KeystrokeEvent]) -> [TimeInterval] {
    let keyDowns = keystrokes.filter { $0.isDown }
    guard keyDowns.count >= 3 else { return [] }

    let modifierMask: UInt = 0xFF0000
    let typingKeys = keyDowns.filter { event in
      let hasModifier = (event.modifiers & modifierMask) != 0
      let isModifierOnly = [55, 54, 56, 60, 58, 61, 59, 62].contains(event.keyCode)
      return !isModifierOnly && !hasModifier
    }
    guard typingKeys.count >= 3 else { return [] }

    var intervals: [TimeInterval] = []
    let burstGap = 0.5
    var burstStart = typingKeys[0].t
    var burstEnd = typingKeys[0].t
    var count = 1

    for i in 1..<typingKeys.count {
      if typingKeys[i].t - burstEnd < burstGap {
        burstEnd = typingKeys[i].t
        count += 1
      } else {
        if count >= 3 {
          intervals.append(TimeInterval(start: burstStart, end: burstEnd))
        }
        burstStart = typingKeys[i].t
        burstEnd = typingKeys[i].t
        count = 1
      }
    }
    if count >= 3 {
      intervals.append(TimeInterval(start: burstStart, end: burstEnd))
    }

    return intervals
  }

  private static func isInTypingInterval(_ time: Double, intervals: [TimeInterval]) -> Bool {
    intervals.contains { time >= $0.start && time <= $0.end }
  }
}
