import AVFoundation
import CoreMedia
import Foundation

extension VideoCompositor {
  struct VideoSegmentInfo {
    let sourceRange: CMTimeRange
    let compositionStart: CMTime
  }

  static func addAudioTracks(
    to composition: AVMutableComposition,
    sources: [AudioSource],
    videoTrimRange: CMTimeRange,
    videoSegments: [VideoSegmentInfo]? = nil
  ) async throws {
    for source in sources {
      let asset = AVURLAsset(url: source.url)
      guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else { continue }

      let compTrack = composition.addMutableTrack(
        withMediaType: .audio,
        preferredTrackID: kCMPersistentTrackID_Invalid
      )

      if let segments = videoSegments, !segments.isEmpty {
        for seg in segments {
          for region in source.regions {
            let overlapStart = CMTimeMaximum(region.start, seg.sourceRange.start)
            let overlapEnd = CMTimeMinimum(region.end, seg.sourceRange.end)
            guard CMTimeCompare(overlapEnd, overlapStart) > 0 else { continue }

            let sourceRange = CMTimeRange(start: overlapStart, end: overlapEnd)
            let offset = CMTimeSubtract(overlapStart, seg.sourceRange.start)
            let insertionTime = CMTimeAdd(seg.compositionStart, offset)

            try compTrack?.insertTimeRange(sourceRange, of: audioTrack, at: insertionTime)
          }
        }
      } else {
        for region in source.regions {
          let overlapStart = CMTimeMaximum(region.start, videoTrimRange.start)
          let overlapEnd = CMTimeMinimum(region.end, videoTrimRange.end)
          guard CMTimeCompare(overlapEnd, overlapStart) > 0 else { continue }

          let sourceRange = CMTimeRange(start: overlapStart, end: overlapEnd)
          let insertionTime = CMTimeSubtract(overlapStart, videoTrimRange.start)

          try compTrack?.insertTimeRange(sourceRange, of: audioTrack, at: insertionTime)
        }
      }
    }
  }

  static func buildAudioMix(
    for composition: AVComposition,
    sources: [AudioSource]
  ) -> AVMutableAudioMix? {
    let audioTracks = composition.tracks(withMediaType: .audio)
    guard !audioTracks.isEmpty else { return nil }

    let needsMix = sources.contains { $0.volume != 1.0 }
    guard needsMix else { return nil }

    let mix = AVMutableAudioMix()
    var params: [AVMutableAudioMixInputParameters] = []

    for (index, track) in audioTracks.enumerated() {
      guard index < sources.count else { break }
      let source = sources[index]
      let inputParams = AVMutableAudioMixInputParameters(track: track)
      inputParams.trackID = track.trackID
      inputParams.setVolume(source.volume, at: .zero)
      params.append(inputParams)
    }

    mix.inputParameters = params
    return mix
  }
}
