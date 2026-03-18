import CoreGraphics
import Foundation

enum CursorEffects {
  static let clickBounceDuration: Double = 0.14
  static let swayMaxRotation: Double = .pi / 18
  static let swaySpeedReference: Double = 1.5
  static let motionBlurMaxSamples: Int = 10
  static let motionBlurMaxOffset: CGFloat = 60

  static func computeSwayRotation(
    dx: CGFloat,
    dy: CGFloat,
    deltaSeconds: Double,
    swayIntensity: CGFloat
  ) -> CGFloat {
    guard swayIntensity > 0, deltaSeconds > 0 else { return 0 }
    let distance = hypot(dx, dy)
    guard distance > 0.0001 else { return 0 }
    let speedPerSecond = Double(distance) / deltaSeconds
    let speedFactor = min(speedPerSecond / swaySpeedReference, 1.0)
    let directionalBias = Double(dx + dy * 0.65) / Double(distance)
    let clampedBias = max(-1.0, min(1.0, directionalBias))
    return CGFloat(clampedBias * speedFactor * swayMaxRotation * Double(swayIntensity) * 3.0)
  }

  static func computeClickBounceScale(
    clicks: [(point: CGPoint, progress: Double)],
    clickBounce: CGFloat
  ) -> CGFloat {
    guard clickBounce > 0 else { return 1.0 }
    for click in clicks {
      let elapsed = click.progress * 0.4
      if elapsed <= clickBounceDuration {
        let bounceProgress = 1.0 - elapsed / clickBounceDuration
        let sineValue = sin(bounceProgress * .pi)
        return CGFloat(max(0.72, 1.0 - sineValue * 0.08 * Double(clickBounce)))
      }
    }
    return 1.0
  }

  static func computeMotionBlurVelocity(
    normalizedDx: CGFloat,
    normalizedDy: CGFloat,
    deltaSeconds: Double,
    blurIntensity: CGFloat,
    outputSize: CGFloat
  ) -> (dx: CGFloat, dy: CGFloat, magnitude: CGFloat) {
    guard blurIntensity > 0, deltaSeconds > 0 else { return (0, 0, 0) }
    let pxDx = normalizedDx * outputSize
    let pxDy = normalizedDy * outputSize
    let speed = hypot(pxDx, pxDy) / CGFloat(deltaSeconds)
    guard speed > 30 else { return (0, 0, 0) }
    let magnitude = min(speed * blurIntensity * 0.025, motionBlurMaxOffset)
    guard magnitude > 1.0 else { return (0, 0, 0) }
    let dist = hypot(pxDx, pxDy)
    let dirX = pxDx / dist
    let dirY = pxDy / dist
    return (dirX * magnitude, dirY * magnitude, magnitude)
  }
}
