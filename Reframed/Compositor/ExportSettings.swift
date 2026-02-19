import AVFoundation
import Foundation

struct ExportSettings: Sendable {
  var format: ExportFormat = .mp4
  var fps: ExportFPS = .original
  var resolution: ExportResolution = .original
  var codec: ExportCodec = .h265
  var audioBitrate: ExportAudioBitrate = .kbps320
  var mode: ExportMode = .normal
  var gifQuality: GIFQuality = .high
}

enum GIFQuality: Sendable, CaseIterable, Identifiable {
  case low
  case medium
  case high
  case maximum

  var id: Self { self }

  var label: String {
    switch self {
    case .low: "Low"
    case .medium: "Medium"
    case .high: "High"
    case .maximum: "Maximum"
    }
  }

  var description: String {
    switch self {
    case .low: "Smallest file size. Noticeable quality loss."
    case .medium: "Good balance of size and quality."
    case .high: "High quality. Recommended for most use cases."
    case .maximum: "Best quality. Larger file size."
    }
  }

  var value: UInt8 {
    switch self {
    case .low: 50
    case .medium: 70
    case .high: 90
    case .maximum: 100
    }
  }
}

enum ExportMode: Sendable, CaseIterable, Identifiable {
  case normal
  case parallel

  var id: Self { self }

  var label: String {
    switch self {
    case .normal: "Normal"
    case .parallel: "Parallel"
    }
  }

  var description: String {
    switch self {
    case .normal: "Standard export pipeline."
    case .parallel: "Multi-core parallel rendering. Faster export."
    }
  }
}

enum ExportFormat: Sendable, CaseIterable, Identifiable {
  case mp4
  case mov
  case gif

  var id: Self { self }

  var label: String {
    switch self {
    case .mp4: "MP4"
    case .mov: "MOV"
    case .gif: "GIF"
    }
  }

  var fileType: AVFileType {
    switch self {
    case .mp4: .mp4
    case .mov: .mov
    case .gif: .mp4
    }
  }

  var fileExtension: String {
    switch self {
    case .mp4: "mp4"
    case .mov: "mov"
    case .gif: "gif"
    }
  }

  var isGIF: Bool {
    self == .gif
  }
}

enum ExportFPS: Sendable, CaseIterable, Identifiable {
  case original
  case fps24
  case fps30
  case fps40
  case fps50
  case fps60

  var id: Self { self }

  var label: String {
    switch self {
    case .original: "Original"
    case .fps24: "24"
    case .fps30: "30"
    case .fps40: "40"
    case .fps50: "50"
    case .fps60: "60"
    }
  }

  func value(fallback: Int) -> Int {
    switch self {
    case .original: fallback
    case .fps24: 24
    case .fps30: 30
    case .fps40: 40
    case .fps50: 50
    case .fps60: 60
    }
  }

  var numericValue: Int? {
    switch self {
    case .original: nil
    case .fps24: 24
    case .fps30: 30
    case .fps40: 40
    case .fps50: 50
    case .fps60: 60
    }
  }
}

enum ExportResolution: Sendable, CaseIterable, Identifiable {
  case original
  case uhd4k
  case fhd1080
  case hd720

  var id: Self { self }

  var label: String {
    switch self {
    case .original: "Original"
    case .uhd4k: "4K"
    case .fhd1080: "1080p"
    case .hd720: "720p"
    }
  }

  var pixelWidth: CGFloat? {
    switch self {
    case .original: nil
    case .uhd4k: 3840
    case .fhd1080: 1920
    case .hd720: 1280
    }
  }
}

enum ExportAudioBitrate: Sendable, CaseIterable, Identifiable {
  case kbps320
  case kbps256
  case kbps192
  case kbps128

  var id: Self { self }

  var label: String {
    switch self {
    case .kbps128: "128"
    case .kbps192: "192"
    case .kbps256: "256"
    case .kbps320: "320"
    }
  }

  var value: Int {
    switch self {
    case .kbps128: 128_000
    case .kbps192: 192_000
    case .kbps256: 256_000
    case .kbps320: 320_000
    }
  }
}

enum ExportCodec: Sendable, CaseIterable, Identifiable {
  case h265
  case h264
  case proRes422
  case proRes4444

  var id: Self { self }

  var label: String {
    switch self {
    case .h264: "H.264"
    case .h265: "H.265 (HEVC)"
    case .proRes422: "ProRes 422"
    case .proRes4444: "ProRes 4444"
    }
  }

  var description: String {
    switch self {
    case .h264: "Widely compatible. Larger file size, works everywhere."
    case .h265: "Better compression. Smaller file size, same quality."
    case .proRes422: "Professional editing codec. Large files, excellent quality."
    case .proRes4444: "Highest quality with alpha channel. Very large files."
    }
  }

  var exportPreset: String {
    switch self {
    case .h264: AVAssetExportPresetHighestQuality
    case .h265: AVAssetExportPresetHEVCHighestQuality
    case .proRes422: AVAssetExportPresetAppleProRes422LPCM
    case .proRes4444: AVAssetExportPresetAppleProRes4444LPCM
    }
  }

  var videoCodecType: AVVideoCodecType {
    switch self {
    case .h264: .h264
    case .h265: .hevc
    case .proRes422: .proRes422
    case .proRes4444: .proRes4444
    }
  }

  var isProRes: Bool {
    switch self {
    case .proRes422, .proRes4444: true
    default: false
    }
  }
}
