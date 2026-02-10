import AVFoundation
import CoreVideo

final class PiPVideoCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
  var sourcePixelBufferAttributes: [String: any Sendable]? {
    [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
  }

  var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] {
    [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
  }

  func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

  func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
    guard let instruction = request.videoCompositionInstruction as? PiPCompositionInstruction else {
      request.finish(with: NSError(domain: "PiPVideoCompositor", code: -1))
      return
    }

    guard let screenBuffer = request.sourceFrame(byTrackID: instruction.screenTrackID) else {
      request.finish(with: NSError(domain: "PiPVideoCompositor", code: -2))
      return
    }

    guard let outputBuffer = request.renderContext.newPixelBuffer() else {
      request.finish(with: NSError(domain: "PiPVideoCompositor", code: -3))
      return
    }

    let width = CVPixelBufferGetWidth(outputBuffer)
    let height = CVPixelBufferGetHeight(outputBuffer)

    CVPixelBufferLockBaseAddress(screenBuffer, .readOnly)
    CVPixelBufferLockBaseAddress(outputBuffer, [])
    defer {
      CVPixelBufferUnlockBaseAddress(screenBuffer, .readOnly)
      CVPixelBufferUnlockBaseAddress(outputBuffer, [])
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
      data: CVPixelBufferGetBaseAddress(outputBuffer),
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: CVPixelBufferGetBytesPerRow(outputBuffer),
      space: colorSpace,
      bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
    ) else {
      request.finish(with: NSError(domain: "PiPVideoCompositor", code: -4))
      return
    }

    let screenImage = createImage(from: screenBuffer, colorSpace: colorSpace)
    if let img = screenImage {
      context.draw(img, in: CGRect(x: 0, y: 0, width: width, height: height))
    }

    if let webcamBuffer = request.sourceFrame(byTrackID: instruction.webcamTrackID) {
      CVPixelBufferLockBaseAddress(webcamBuffer, .readOnly)
      defer { CVPixelBufferUnlockBaseAddress(webcamBuffer, .readOnly) }

      if let webcamImage = createImage(from: webcamBuffer, colorSpace: colorSpace) {
        let pipRect = instruction.pipRect
        let flippedY = CGFloat(height) - pipRect.origin.y - pipRect.height
        let drawRect = CGRect(x: pipRect.origin.x, y: flippedY, width: pipRect.width, height: pipRect.height)

        let path = CGPath(roundedRect: drawRect, cornerWidth: instruction.cornerRadius, cornerHeight: instruction.cornerRadius, transform: nil)
        context.saveGState()
        context.addPath(path)
        context.clip()
        context.draw(webcamImage, in: drawRect)
        context.restoreGState()
      }
    }

    request.finish(withComposedVideoFrame: outputBuffer)
  }

  private func createImage(from pixelBuffer: CVPixelBuffer, colorSpace: CGColorSpace) -> CGImage? {
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

    guard let ctx = CGContext(
      data: baseAddress,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: bytesPerRow,
      space: colorSpace,
      bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
    ) else { return nil }

    return ctx.makeImage()
  }
}
