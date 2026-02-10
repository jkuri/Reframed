import AVFoundation
import AppKit
import CoreGraphics

@MainActor
@Observable
final class ThumbnailGenerator {
  private(set) var thumbnails: [NSImage] = []
  private(set) var isGenerating = false
  private let count: Int

  init(count: Int = 20) {
    self.count = count
  }

  func generate(from url: URL) async {
    isGenerating = true
    defer { isGenerating = false }

    let asset = AVURLAsset(url: url)
    guard let duration = try? await asset.load(.duration) else { return }
    let totalSeconds = CMTimeGetSeconds(duration)
    guard totalSeconds > 0 else { return }

    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 160, height: 90)
    generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 10)
    generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 10)

    var times: [CMTime] = []
    for i in 0..<count {
      let seconds = totalSeconds * Double(i) / Double(count)
      times.append(CMTime(seconds: seconds, preferredTimescale: 600))
    }

    var results: [NSImage] = []
    for time in times {
      if let cgImage = try? await generator.image(at: time).image {
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        results.append(image)
      }
    }
    thumbnails = results
  }
}
