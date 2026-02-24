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
    clicks: [CursorClickEvent] = []
  ) -> [CursorSample] {
    guard samples.count >= 2 else { return samples }

    let tension = speed.tension
    let friction = speed.friction
    let mass = speed.mass
    let convergence = speed.convergenceDuration
    let sortedClicks = clicks.sorted { $0.t < $1.t }
    var clickIdx = 0

    var result: [CursorSample] = []
    result.reserveCapacity(samples.count)

    var posX = samples[0].x
    var posY = samples[0].y
    var velX = 0.0
    var velY = 0.0

    result.append(CursorSample(t: samples[0].t, x: posX, y: posY, p: samples[0].p))

    for i in 1..<samples.count {
      let target = samples[i]
      let prev = samples[i - 1]
      let dt = target.t - prev.t
      guard dt > 0 && dt < 1.0 else {
        posX = target.x
        posY = target.y
        velX = 0
        velY = 0
        result.append(CursorSample(t: target.t, x: posX, y: posY, p: target.p))
        while clickIdx < sortedClicks.count && sortedClicks[clickIdx].t <= target.t {
          clickIdx += 1
        }
        continue
      }

      let steps = max(1, Int(ceil(dt / 0.001)))
      let stepDt = dt / Double(steps)

      for _ in 0..<steps {
        let accelX = (tension * (target.x - posX) - friction * velX) / mass
        let accelY = (tension * (target.y - posY) - friction * velY) / mass
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
          result.append(CursorSample(t: target.t, x: posX, y: posY, p: target.p))
          clickIdx += 1
          continue
        }
      }

      var outX = posX
      var outY = posY

      if clickIdx < sortedClicks.count {
        let click = sortedClicks[clickIdx]
        let timeToClick = click.t - target.t
        if timeToClick > 0 && timeToClick <= convergence {
          let raw = 1.0 - timeToClick / convergence
          let blend = raw * raw * (3.0 - 2.0 * raw)
          outX = posX + (click.x - posX) * blend
          outY = posY + (click.y - posY) * blend
        }
      }

      result.append(CursorSample(t: target.t, x: outX, y: outY, p: target.p))
    }

    return result
  }
}
