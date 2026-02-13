import AVFoundation
import Accelerate
import Foundation

@MainActor
@Observable
final class AudioWaveformGenerator {
  private(set) var samples: [Float] = []
  private(set) var isGenerating = false

  func generate(from url: URL, count: Int = 200) async {
    isGenerating = true
    defer { isGenerating = false }

    let result = await Task.detached(priority: .userInitiated) {
      await Self.extractSamples(from: url, count: count)
    }.value

    samples = result
  }

  nonisolated private static func extractSamples(from url: URL, count: Int) async -> [Float] {
    let asset = AVURLAsset(url: url)
    guard let reader = try? AVAssetReader(asset: asset) else { return [] }

    let audioTracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
    guard let track = audioTracks.first else {
      let videoTracks = (try? await asset.loadTracks(withMediaType: .video)) ?? []
      guard videoTracks.first != nil else { return [] }
      return []
    }

    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ]

    let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
    reader.add(output)
    guard reader.startReading() else { return [] }

    var allSamples: [Int16] = []
    while let buffer = output.copyNextSampleBuffer() {
      guard let blockBuffer = CMSampleBufferGetDataBuffer(buffer) else { continue }
      let length = CMBlockBufferGetDataLength(blockBuffer)
      var data = Data(count: length)
      data.withUnsafeMutableBytes { ptr in
        guard let base = ptr.baseAddress else { return }
        CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: base)
      }
      let sampleCount = length / MemoryLayout<Int16>.size
      data.withUnsafeBytes { ptr in
        guard let bound = ptr.bindMemory(to: Int16.self).baseAddress else { return }
        allSamples.append(contentsOf: UnsafeBufferPointer(start: bound, count: sampleCount))
      }
    }

    guard !allSamples.isEmpty else { return [] }
    return downsample(allSamples, to: count)
  }

  nonisolated private static func downsample(_ raw: [Int16], to count: Int) -> [Float] {
    let total = raw.count
    guard total > 0 && count > 0 else { return [] }

    let bucketSize = max(1, total / count)
    var result: [Float] = []
    result.reserveCapacity(count)

    for i in 0..<count {
      let start = i * total / count
      let end = min(start + bucketSize, total)
      guard start < end else {
        result.append(0)
        continue
      }

      var maxVal: Float = 0
      for j in start..<end {
        let absVal = Float(abs(Int32(raw[j])))
        if absVal > maxVal { maxVal = absVal }
      }
      result.append(maxVal / 32768.0)
    }

    let peak = result.max() ?? 1.0
    guard peak > 0 else { return result }
    return result.map { $0 / peak }
  }
}
