import Foundation

extension EditorState {
  var activeCursorProvider: CursorMetadataProvider? {
    cursorMovementEnabled ? smoothedCursorProvider : cursorMetadataProvider
  }

  func regenerateSmoothedCursor() {
    guard let provider = cursorMetadataProvider else {
      smoothedCursorProvider = nil
      return
    }
    guard cursorMovementEnabled else {
      smoothedCursorProvider = nil
      return
    }
    let smoothedSamples = CursorSmoothing.smooth(
      samples: provider.metadata.samples,
      speed: cursorMovementSpeed,
      clicks: provider.metadata.clicks,
      zoomTimeline: zoomTimeline,
      keystrokes: provider.metadata.keystrokes
    )
    var smoothedMetadata = provider.metadata
    smoothedMetadata.samples = smoothedSamples
    smoothedCursorProvider = CursorMetadataProvider(metadata: smoothedMetadata)
  }
}
