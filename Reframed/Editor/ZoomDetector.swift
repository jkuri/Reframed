import Foundation

struct ZoomDetectorConfig: Codable, Sendable {
  var zoomLevel: Double = 2.0
  var dwellThresholdSeconds: Double = 0.5
  var transitionDuration: Double = 0.4
}

enum ZoomDetector {
  static func detect(from metadata: CursorMetadataFile, duration: Double, config: ZoomDetectorConfig) -> [ZoomKeyframe] {
    let clicks = metadata.clicks
    guard !clicks.isEmpty else { return [] }

    struct ClickRegion {
      var startTime: Double
      var endTime: Double
      var centerX: Double
      var centerY: Double
      var clickCount: Int
    }

    var regions: [ClickRegion] = []

    for click in clicks {
      guard click.t >= 0 && click.t <= duration else { continue }

      if var last = regions.last {
        let gap = click.t - last.endTime
        if gap < config.dwellThresholdSeconds {
          let totalClicks = last.clickCount + 1
          last.centerX = (last.centerX * Double(last.clickCount) + click.x) / Double(totalClicks)
          last.centerY = (last.centerY * Double(last.clickCount) + click.y) / Double(totalClicks)
          last.endTime = click.t
          last.clickCount = totalClicks
          regions[regions.count - 1] = last
          continue
        }
      }

      regions.append(
        ClickRegion(
          startTime: click.t,
          endTime: click.t,
          centerX: click.x,
          centerY: click.y,
          clickCount: 1
        )
      )
    }

    var keyframes: [ZoomKeyframe] = []

    let holdDuration = max(config.dwellThresholdSeconds, 0.5)

    var mergedRegions: [ClickRegion] = []
    for region in regions {
      if var last = mergedRegions.last {
        let lastHoldEnd = max(last.endTime, last.startTime + holdDuration)
        let lastZoomOut = min(duration, lastHoldEnd + config.transitionDuration)
        let thisZoomIn = max(0, region.startTime - config.transitionDuration)

        if lastZoomOut > thisZoomIn {
          let totalClicks = last.clickCount + region.clickCount
          last.centerX = (last.centerX * Double(last.clickCount) + region.centerX * Double(region.clickCount)) / Double(totalClicks)
          last.centerY = (last.centerY * Double(last.clickCount) + region.centerY * Double(region.clickCount)) / Double(totalClicks)
          last.endTime = region.endTime
          last.clickCount = totalClicks
          mergedRegions[mergedRegions.count - 1] = last
          continue
        }
      }
      mergedRegions.append(region)
    }

    for region in mergedRegions {
      let holdEnd = max(region.endTime, region.startTime + holdDuration)
      let zoomInTime = max(0, region.startTime - config.transitionDuration)
      let zoomOutTime = min(duration, holdEnd + config.transitionDuration)

      keyframes.append(
        ZoomKeyframe(
          t: zoomInTime,
          zoomLevel: 1.0,
          centerX: region.centerX,
          centerY: region.centerY,
          isAuto: true
        )
      )

      keyframes.append(
        ZoomKeyframe(
          t: region.startTime,
          zoomLevel: config.zoomLevel,
          centerX: region.centerX,
          centerY: region.centerY,
          isAuto: true
        )
      )

      keyframes.append(
        ZoomKeyframe(
          t: holdEnd,
          zoomLevel: config.zoomLevel,
          centerX: region.centerX,
          centerY: region.centerY,
          isAuto: true
        )
      )

      keyframes.append(
        ZoomKeyframe(
          t: zoomOutTime,
          zoomLevel: 1.0,
          centerX: region.centerX,
          centerY: region.centerY,
          isAuto: true
        )
      )
    }

    keyframes.sort { $0.t < $1.t }
    return keyframes
  }
}
