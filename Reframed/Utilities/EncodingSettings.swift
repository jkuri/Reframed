import AVFoundation
import VideoToolbox

enum EncodingSettings {
  nonisolated(unsafe) static let bt709ColorProperties: [String: Any] = [
    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
  ]

  static func exportVideoSettings(
    codec: AVVideoCodecType,
    width: Int,
    height: Int,
    fps: Int,
    isHDR: Bool = false
  ) -> [String: Any] {
    if codec == .proRes4444 || codec == .proRes422 {
      var settings: [String: Any] = [
        AVVideoCodecKey: codec,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
      ]
      if !isHDR {
        settings[AVVideoColorPropertiesKey] = bt709ColorProperties
      }
      return settings
    }
    let pixels = Double(width * height)
    var compressionProperties: [String: Any] = [
      AVVideoMaxKeyFrameIntervalKey: fps,
      AVVideoExpectedSourceFrameRateKey: fps,
    ]
    if codec == .hevc {
      compressionProperties[AVVideoAverageBitRateKey] = pixels * (isHDR ? 7 : 5)
      compressionProperties[AVVideoProfileLevelKey] = kVTProfileLevel_HEVC_Main10_AutoLevel
    } else {
      compressionProperties[AVVideoAverageBitRateKey] = pixels * 7
      compressionProperties[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
    }
    var settings: [String: Any] = [
      AVVideoCodecKey: codec,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoCompressionPropertiesKey: compressionProperties,
    ]
    if !isHDR {
      settings[AVVideoColorPropertiesKey] = bt709ColorProperties
    }
    return settings
  }

  static func captureVideoSettings(
    quality: CaptureQuality,
    width: Int,
    height: Int,
    fps: Int,
    isWebcam: Bool,
    isHDR: Bool = false
  ) -> [String: Any] {
    switch quality {
    case .standard:
      let bitRateMultiplier = isWebcam ? 2 : (isHDR ? 7 : 5)
      var settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.hevc,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
          AVVideoAverageBitRateKey: width * height * bitRateMultiplier,
          AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main10_AutoLevel,
          AVVideoExpectedSourceFrameRateKey: fps,
          AVVideoAllowFrameReorderingKey: false,
        ] as [String: Any],
      ]
      if !isHDR {
        settings[AVVideoColorPropertiesKey] = bt709ColorProperties
      }
      return settings
    case .high:
      var settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.proRes422,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
      ]
      if !isHDR {
        settings[AVVideoColorPropertiesKey] = bt709ColorProperties
      }
      return settings
    case .veryHigh:
      var settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.proRes4444,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
      ]
      if !isHDR {
        settings[AVVideoColorPropertiesKey] = bt709ColorProperties
      }
      return settings
    }
  }

  static func aacAudioSettings(bitrate: Int = 320_000) -> [String: Any] {
    [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVNumberOfChannelsKey: 2,
      AVSampleRateKey: 48000,
      AVEncoderBitRateKey: bitrate,
    ]
  }
}
