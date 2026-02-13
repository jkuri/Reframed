import Foundation

struct ZoomDetectorConfig: Codable, Sendable {
  var zoomLevel: Double = 2.0
  var dwellThresholdSeconds: Double = 0.5
  var velocityThreshold: Double = 0.05
  var minZoomDuration: Double = 1.0
  var transitionDuration: Double = 0.4
}

enum ZoomDetector {
  static func detect(from metadata: CursorMetadataFile, duration: Double, config: ZoomDetectorConfig) -> [ZoomKeyframe] {
    let samples = metadata.samples
    guard samples.count > 10 else { return [] }

    let velocityWindowSec = 0.3
    let sampleRate = Double(metadata.sampleRateHz)
    let velocityWindowSamples = max(1, Int(velocityWindowSec * sampleRate))

    var velocities: [Double] = Array(repeating: 0, count: samples.count)
    for i in velocityWindowSamples..<samples.count {
      let dx = samples[i].x - samples[i - velocityWindowSamples].x
      let dy = samples[i].y - samples[i - velocityWindowSamples].y
      let dt = samples[i].t - samples[i - velocityWindowSamples].t
      if dt > 0 {
        velocities[i] = sqrt(dx * dx + dy * dy) / dt
      }
    }

    struct DwellRegion {
      var startIdx: Int
      var endIdx: Int
      var avgX: Double
      var avgY: Double
    }

    var regions: [DwellRegion] = []
    var dwellStart: Int?
    var sumX = 0.0
    var sumY = 0.0
    var count = 0

    for i in 0..<samples.count {
      if velocities[i] < config.velocityThreshold {
        if dwellStart == nil {
          dwellStart = i
          sumX = 0
          sumY = 0
          count = 0
        }
        sumX += samples[i].x
        sumY += samples[i].y
        count += 1
      } else {
        if let start = dwellStart, count > 0 {
          let dwellDuration = samples[i - 1].t - samples[start].t
          if dwellDuration >= config.dwellThresholdSeconds {
            regions.append(
              DwellRegion(
                startIdx: start,
                endIdx: i - 1,
                avgX: sumX / Double(count),
                avgY: sumY / Double(count)
              )
            )
          }
        }
        dwellStart = nil
      }
    }

    if let start = dwellStart, count > 0 {
      let dwellDuration = samples[samples.count - 1].t - samples[start].t
      if dwellDuration >= config.dwellThresholdSeconds {
        regions.append(
          DwellRegion(
            startIdx: start,
            endIdx: samples.count - 1,
            avgX: sumX / Double(count),
            avgY: sumY / Double(count)
          )
        )
      }
    }

    var merged: [DwellRegion] = []
    for region in regions {
      if let last = merged.last {
        let gap = samples[region.startIdx].t - samples[last.endIdx].t
        if gap < config.transitionDuration * 2 {
          let totalCount = (last.endIdx - last.startIdx + 1) + (region.endIdx - region.startIdx + 1)
          let lastCount = last.endIdx - last.startIdx + 1
          let regionCount = region.endIdx - region.startIdx + 1
          let avgX = (last.avgX * Double(lastCount) + region.avgX * Double(regionCount)) / Double(totalCount)
          let avgY = (last.avgY * Double(lastCount) + region.avgY * Double(regionCount)) / Double(totalCount)
          merged[merged.count - 1] = DwellRegion(
            startIdx: last.startIdx,
            endIdx: region.endIdx,
            avgX: avgX,
            avgY: avgY
          )
          continue
        }
      }
      merged.append(region)
    }

    var keyframes: [ZoomKeyframe] = []

    for region in merged {
      let regionDuration = samples[region.endIdx].t - samples[region.startIdx].t
      guard regionDuration >= config.minZoomDuration else { continue }

      let zoomInTime = max(0, samples[region.startIdx].t - config.transitionDuration)
      let zoomOutTime = min(duration, samples[region.endIdx].t + config.transitionDuration)

      keyframes.append(
        ZoomKeyframe(
          t: zoomInTime,
          zoomLevel: 1.0,
          centerX: region.avgX,
          centerY: region.avgY,
          isAuto: true
        )
      )

      keyframes.append(
        ZoomKeyframe(
          t: samples[region.startIdx].t,
          zoomLevel: config.zoomLevel,
          centerX: region.avgX,
          centerY: region.avgY,
          isAuto: true
        )
      )

      keyframes.append(
        ZoomKeyframe(
          t: samples[region.endIdx].t,
          zoomLevel: config.zoomLevel,
          centerX: region.avgX,
          centerY: region.avgY,
          isAuto: true
        )
      )

      keyframes.append(
        ZoomKeyframe(
          t: zoomOutTime,
          zoomLevel: 1.0,
          centerX: region.avgX,
          centerY: region.avgY,
          isAuto: true
        )
      )
    }

    keyframes.sort { $0.t < $1.t }
    return keyframes
  }
}
