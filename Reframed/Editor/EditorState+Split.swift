import CoreMedia
import Foundation

extension EditorState {
  static let minSplitPiece = 0.05

  func canSplit(start: Double, end: Double, at time: Double) -> Bool {
    time - start >= Self.minSplitPiece && end - time >= Self.minSplitPiece
  }

  func splitAllRegionsAtPlayhead() {
    splitAllRegions(atTime: CMTimeGetSeconds(currentTime))
  }

  func splitAllRegions(atTime time: Double) {
    splitVideoRegion(atTime: time)
    splitAudioRegions(atTime: time)
    splitCameraRegion(atTime: time)
    splitSpotlightRegion(atTime: time)
  }

  private func splitAudioRegions(atTime time: Double) {
    for track in [AudioTrackType.system, .mic] {
      var regs = regions(for: track)
      guard let idx = regs.firstIndex(where: { canSplit(start: $0.startSeconds, end: $0.endSeconds, at: time) }) else {
        continue
      }
      let original = regs[idx]
      regs.replaceSubrange(
        idx...idx,
        with: [
          AudioRegionData(startSeconds: original.startSeconds, endSeconds: time),
          AudioRegionData(startSeconds: time, endSeconds: original.endSeconds),
        ]
      )
      setRegions(regs, for: track)
    }
  }

  private func splitCameraRegion(atTime time: Double) {
    guard let idx = cameraRegions.firstIndex(where: { canSplit(start: $0.startSeconds, end: $0.endSeconds, at: time) })
    else { return }
    var head = cameraRegions[idx]
    var tail = head
    head.endSeconds = time
    head.exitTransition = nil
    head.exitTransitionDuration = nil
    tail.id = UUID()
    tail.startSeconds = time
    tail.entryTransition = nil
    tail.entryTransitionDuration = nil
    cameraRegions.replaceSubrange(idx...idx, with: [head, tail])
  }

  private func splitSpotlightRegion(atTime time: Double) {
    guard
      let idx = spotlightRegions.firstIndex(where: { canSplit(start: $0.startSeconds, end: $0.endSeconds, at: time) })
    else { return }
    var head = spotlightRegions[idx]
    var tail = head
    head.endSeconds = time
    tail.id = UUID()
    tail.startSeconds = time
    spotlightRegions.replaceSubrange(idx...idx, with: [head, tail])
  }
}
