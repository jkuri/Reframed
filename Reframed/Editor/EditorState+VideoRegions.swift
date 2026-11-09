import CoreMedia
import Foundation

extension EditorState {
  func addVideoRegion(atTime time: Double) {
    if videoRegions.contains(where: { time >= $0.startSeconds && time <= $0.endSeconds }) {
      return
    }

    let dur = CMTimeGetSeconds(duration)
    let desiredHalf = min(5.0, dur / 2)
    var gapStart: Double = 0
    var gapEnd: Double = dur
    var insertIdx = videoRegions.count

    for i in 0..<videoRegions.count {
      if time < videoRegions[i].startSeconds {
        gapEnd = videoRegions[i].startSeconds
        insertIdx = i
        break
      }
      gapStart = videoRegions[i].endSeconds
    }
    if insertIdx == videoRegions.count {
      gapEnd = dur
    }

    guard gapEnd - gapStart >= 0.05 else { return }

    let regionStart = max(gapStart, time - desiredHalf)
    let regionEnd = min(gapEnd, time + desiredHalf)
    let finalStart = max(gapStart, min(regionStart, regionEnd - 0.05))
    let finalEnd = min(gapEnd, max(regionEnd, finalStart + 0.05))

    videoRegions.insert(
      VideoRegionData(startSeconds: finalStart, endSeconds: finalEnd),
      at: insertIdx
    )
    videoRegions.sort { $0.startSeconds < $1.startSeconds }
  }

  @discardableResult
  func splitVideoRegion(atTime time: Double) -> Bool {
    let minPiece = 0.05
    guard let idx = videoRegions.firstIndex(where: { time - $0.startSeconds >= minPiece && $0.endSeconds - time >= minPiece }) else {
      return false
    }
    let original = videoRegions[idx]
    var head = VideoRegionData(startSeconds: original.startSeconds, endSeconds: time)
    head.entryTransition = original.entryTransition
    head.entryTransitionDuration = original.entryTransitionDuration
    var tail = VideoRegionData(startSeconds: time, endSeconds: original.endSeconds)
    tail.exitTransition = original.exitTransition
    tail.exitTransitionDuration = original.exitTransitionDuration
    videoRegions.replaceSubrange(idx...idx, with: [head, tail])
    return true
  }

  func splitVideoRegionAtPlayhead() {
    splitVideoRegion(atTime: CMTimeGetSeconds(currentTime))
  }

  func removeVideoRegion(regionId: UUID) {
    videoRegions.removeAll { $0.id == regionId }
  }

  func updateVideoRegionStart(regionId: UUID, newStart: Double) {
    guard let idx = videoRegions.firstIndex(where: { $0.id == regionId }) else { return }
    let dur = CMTimeGetSeconds(duration)
    let minStart: Double = idx > 0 ? videoRegions[idx - 1].endSeconds : 0
    let maxStart = videoRegions[idx].endSeconds - 0.01
    videoRegions[idx].startSeconds = max(minStart, min(maxStart, min(dur, newStart)))
    videoRegions.sort { $0.startSeconds < $1.startSeconds }
  }

  func updateVideoRegionEnd(regionId: UUID, newEnd: Double) {
    guard let idx = videoRegions.firstIndex(where: { $0.id == regionId }) else { return }
    let dur = CMTimeGetSeconds(duration)
    let maxEnd: Double = idx < videoRegions.count - 1 ? videoRegions[idx + 1].startSeconds : dur
    let minEnd = videoRegions[idx].startSeconds + 0.01
    videoRegions[idx].endSeconds = max(minEnd, min(maxEnd, newEnd))
    videoRegions.sort { $0.startSeconds < $1.startSeconds }
  }

  func moveVideoRegion(regionId: UUID, newStart: Double) {
    guard let idx = videoRegions.firstIndex(where: { $0.id == regionId }) else { return }
    let dur = CMTimeGetSeconds(duration)
    let regionDuration = videoRegions[idx].endSeconds - videoRegions[idx].startSeconds
    let minStart: Double = idx > 0 ? videoRegions[idx - 1].endSeconds : 0
    let maxStart: Double = (idx < videoRegions.count - 1 ? videoRegions[idx + 1].startSeconds : dur) - regionDuration
    let clampedStart = max(minStart, min(maxStart, newStart))
    videoRegions[idx].startSeconds = clampedStart
    videoRegions[idx].endSeconds = clampedStart + regionDuration
    videoRegions.sort { $0.startSeconds < $1.startSeconds }
  }

  func updateVideoRegionTransition(
    regionId: UUID,
    entryTransition: RegionTransitionType? = nil,
    entryDuration: Double? = nil,
    exitTransition: RegionTransitionType? = nil,
    exitDuration: Double? = nil
  ) {
    guard let idx = videoRegions.firstIndex(where: { $0.id == regionId }) else { return }
    if let entryTransition { videoRegions[idx].entryTransition = entryTransition }
    if let entryDuration { videoRegions[idx].entryTransitionDuration = entryDuration }
    if let exitTransition { videoRegions[idx].exitTransition = exitTransition }
    if let exitDuration { videoRegions[idx].exitTransitionDuration = exitDuration }
  }
}
