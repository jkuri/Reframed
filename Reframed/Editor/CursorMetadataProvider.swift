import CoreGraphics
import Foundation

private func cursorBinarySearch(samples: [CursorSample], time: Double) -> Int {
  var lo = 0
  var hi = samples.count - 1
  while lo < hi {
    let mid = (lo + hi + 1) / 2
    if samples[mid].t <= time {
      lo = mid
    } else {
      hi = mid - 1
    }
  }
  return lo
}

private func cursorSample(samples: [CursorSample], at time: Double) -> CGPoint {
  guard !samples.isEmpty else { return CGPoint(x: 0.5, y: 0.5) }
  let idx = cursorBinarySearch(samples: samples, time: time)
  let s0 = samples[idx]
  guard idx + 1 < samples.count else { return CGPoint(x: s0.x, y: s0.y) }
  let s1 = samples[idx + 1]
  let dt = s1.t - s0.t
  guard dt > 0 else { return CGPoint(x: s0.x, y: s0.y) }
  let t = (time - s0.t) / dt
  return CGPoint(x: s0.x + (s1.x - s0.x) * t, y: s0.y + (s1.y - s0.y) * t)
}

private func cursorTypeAtTime(samples: [CursorSample], at time: Double) -> SystemCursorType {
  guard !samples.isEmpty else { return .arrow }
  let idx = cursorBinarySearch(samples: samples, time: time)
  let rawType = samples[idx].c ?? 0
  return SystemCursorType(rawValue: rawType) ?? .arrow
}

private func cursorActiveClicks(
  clicks: [CursorClickEvent],
  at time: Double,
  within duration: Double
) -> [(point: CGPoint, progress: Double)] {
  var result: [(point: CGPoint, progress: Double)] = []
  for click in clicks {
    let elapsed = time - click.t
    if elapsed >= 0 && elapsed <= duration {
      result.append((CGPoint(x: click.x, y: click.y), elapsed / duration))
    }
  }
  return result
}

final class CursorMetadataProvider: @unchecked Sendable {
  let metadata: CursorMetadataFile

  init(metadata: CursorMetadataFile) {
    self.metadata = metadata
  }

  static func load(from url: URL) throws -> CursorMetadataProvider {
    let data = try Data(contentsOf: url)
    let file = try JSONDecoder().decode(CursorMetadataFile.self, from: data)
    return CursorMetadataProvider(metadata: file)
  }

  func sample(at time: Double) -> CGPoint {
    cursorSample(samples: metadata.samples, at: time)
  }

  func cursorType(at time: Double) -> SystemCursorType {
    cursorTypeAtTime(samples: metadata.samples, at: time)
  }

  func activeClicks(at time: Double, within duration: Double = 0.4) -> [(point: CGPoint, progress: Double)] {
    cursorActiveClicks(clicks: metadata.clicks, at: time, within: duration)
  }

  func clickEvents(from startTime: Double, to endTime: Double) -> [(time: Double, button: Int)] {
    metadata.clicks.compactMap { click in
      guard click.t > startTime, click.t <= endTime else { return nil }
      return (time: click.t, button: click.button)
    }
  }

  func makeSnapshot() -> CursorMetadataSnapshot {
    CursorMetadataSnapshot(
      samples: metadata.samples,
      clicks: metadata.clicks,
      captureAreaWidth: metadata.captureAreaWidth,
      captureAreaHeight: metadata.captureAreaHeight
    )
  }
}

final class CursorMetadataSnapshot: @unchecked Sendable {
  let samples: [CursorSample]
  let clicks: [CursorClickEvent]
  let captureAreaWidth: Double
  let captureAreaHeight: Double

  init(samples: [CursorSample], clicks: [CursorClickEvent], captureAreaWidth: Double, captureAreaHeight: Double) {
    self.samples = samples
    self.clicks = clicks
    self.captureAreaWidth = captureAreaWidth
    self.captureAreaHeight = captureAreaHeight
  }

  func sample(at time: Double) -> CGPoint {
    cursorSample(samples: samples, at: time)
  }

  func cursorType(at time: Double) -> SystemCursorType {
    cursorTypeAtTime(samples: samples, at: time)
  }

  func activeClicks(at time: Double, within duration: Double = 0.4) -> [(point: CGPoint, progress: Double)] {
    cursorActiveClicks(clicks: clicks, at: time, within: duration)
  }
}
