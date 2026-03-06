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
    fps: Int
  ) -> [String: Any] {
    if codec == .proRes4444 || codec == .proRes422 {
      return [
        AVVideoCodecKey: codec,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoColorPropertiesKey: bt709ColorProperties,
      ]
    }
    let pixels = Double(width * height)
    var compressionProperties: [String: Any] = [
      AVVideoMaxKeyFrameIntervalKey: fps,
      AVVideoExpectedSourceFrameRateKey: fps,
    ]
    if codec == .hevc {
      compressionProperties[AVVideoAverageBitRateKey] = pixels * 5
      compressionProperties[AVVideoProfileLevelKey] = kVTProfileLevel_HEVC_Main10_AutoLevel
    } else {
      compressionProperties[AVVideoAverageBitRateKey] = pixels * 7
      compressionProperties[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
    }
    return [
      AVVideoCodecKey: codec,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoColorPropertiesKey: bt709ColorProperties,
      AVVideoCompressionPropertiesKey: compressionProperties,
    ]
  }

  static func captureVideoSettings(
    quality: CaptureQuality,
    width: Int,
    height: Int,
    fps: Int,
    isWebcam: Bool
  ) -> [String: Any] {
    switch quality {
    case .standard:
      let bitRateMultiplier = isWebcam ? 2 : 5
      return [
        AVVideoCodecKey: AVVideoCodecType.hevc,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoColorPropertiesKey: bt709ColorProperties,
        AVVideoCompressionPropertiesKey: [
          AVVideoAverageBitRateKey: width * height * bitRateMultiplier,
          AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main10_AutoLevel,
          AVVideoExpectedSourceFrameRateKey: fps,
          AVVideoAllowFrameReorderingKey: false,
        ] as [String: Any],
      ]
    case .high:
      return [
        AVVideoCodecKey: AVVideoCodecType.proRes422,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoColorPropertiesKey: bt709ColorProperties,
      ]
    case .veryHigh:
      return [
        AVVideoCodecKey: AVVideoCodecType.proRes4444,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoColorPropertiesKey: bt709ColorProperties,
      ]
    }
  }

  static func aacAudioSettings(bitrate: Int = 320_000) -> [String: Any] {
    [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVNumberOfChannelsKey: 2,
      AVSampleRateKey: 44100,
      AVEncoderBitRateKey: bitrate,
    ]
  }
}
