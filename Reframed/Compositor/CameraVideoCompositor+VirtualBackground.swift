import CoreVideo

extension CameraVideoCompositor {
  static func processWebcamWithVirtualBackground(
    webcamBuffer: CVPixelBuffer,
    instruction: CompositionInstruction,
    processor: PersonSegmentationProcessor
  ) -> CGImage? {
    guard instruction.cameraBackgroundStyle != .none else { return nil }
    return processor.processFrame(
      webcamBuffer: webcamBuffer,
      style: instruction.cameraBackgroundStyle,
      backgroundCGImage: instruction.cameraBackgroundImage
    )
  }
}
