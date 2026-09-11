import CoreMedia
import Foundation

enum TimeLapse {
  static let range: ClosedRange<Double> = 1.0...16.0

  static func clamp(_ speed: Double) -> Double {
    guard !speed.isNaN else { return range.lowerBound }
    return min(max(speed, range.lowerBound), range.upperBound)
  }

  static func frameCount(duration: CMTime, fps: Int, speed: Double) -> Int {
    guard duration.isValid, fps > 0 else { return 0 }
    let seconds = CMTimeGetSeconds(duration)
    guard seconds.isFinite, seconds > 0 else { return 0 }
    return Int(ceil(seconds / clamp(speed) * Double(fps)))
  }

  static func sourceTime(forOutput outputTime: CMTime, speed: Double) -> CMTime {
    CMTimeMultiplyByFloat64(outputTime, multiplier: clamp(speed))
  }

  static func effectiveDuration(seconds: Double, speed: Double) -> Double {
    guard seconds.isFinite, seconds > 0 else { return 0 }
    return seconds / clamp(speed)
  }

  static func dropsAudio(speed: Double) -> Bool {
    clamp(speed) > range.lowerBound
  }
}
