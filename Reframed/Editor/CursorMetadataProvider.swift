import CoreGraphics
import Foundation

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
    let samples = metadata.samples
    guard !samples.isEmpty else { return CGPoint(x: 0.5, y: 0.5) }
    let idx = binarySearch(samples: samples, time: time)
    let s0 = samples[idx]
    guard idx + 1 < samples.count else { return CGPoint(x: s0.x, y: s0.y) }
    let s1 = samples[idx + 1]
    let dt = s1.t - s0.t
    guard dt > 0 else { return CGPoint(x: s0.x, y: s0.y) }
    let t = (time - s0.t) / dt
    return CGPoint(x: s0.x + (s1.x - s0.x) * t, y: s0.y + (s1.y - s0.y) * t)
  }

  func isPressed(at time: Double) -> Bool {
    let samples = metadata.samples
    guard !samples.isEmpty else { return false }
    let idx = binarySearch(samples: samples, time: time)
    return samples[idx].p
  }

  func activeClicks(at time: Double, within duration: Double = 0.4) -> [(point: CGPoint, progress: Double)] {
    var result: [(point: CGPoint, progress: Double)] = []
    for click in metadata.clicks {
      let elapsed = time - click.t
      if elapsed >= 0 && elapsed <= duration {
        let progress = elapsed / duration
        result.append((CGPoint(x: click.x, y: click.y), progress))
      }
    }
    return result
  }

  func makeSnapshot() -> CursorMetadataSnapshot {
    CursorMetadataSnapshot(
      samples: metadata.samples,
      clicks: metadata.clicks,
      captureAreaWidth: metadata.captureAreaWidth,
      captureAreaHeight: metadata.captureAreaHeight
    )
  }

  private func binarySearch(samples: [CursorSample], time: Double) -> Int {
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
    guard !samples.isEmpty else { return CGPoint(x: 0.5, y: 0.5) }
    let idx = binarySearch(time: time)
    let s0 = samples[idx]
    guard idx + 1 < samples.count else { return CGPoint(x: s0.x, y: s0.y) }
    let s1 = samples[idx + 1]
    let dt = s1.t - s0.t
    guard dt > 0 else { return CGPoint(x: s0.x, y: s0.y) }
    let t = (time - s0.t) / dt
    return CGPoint(x: s0.x + (s1.x - s0.x) * t, y: s0.y + (s1.y - s0.y) * t)
  }

  func activeClicks(at time: Double, within duration: Double = 0.4) -> [(point: CGPoint, progress: Double)] {
    var result: [(point: CGPoint, progress: Double)] = []
    for click in clicks {
      let elapsed = time - click.t
      if elapsed >= 0 && elapsed <= duration {
        result.append((CGPoint(x: click.x, y: click.y), elapsed / duration))
      }
    }
    return result
  }

  private func binarySearch(time: Double) -> Int {
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
}
