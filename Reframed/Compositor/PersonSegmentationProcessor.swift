import CoreGraphics
import CoreImage
import Vision

final class SegmentationProcessorPool: @unchecked Sendable {
  private let condition = NSCondition()
  private var available: [PersonSegmentationProcessor] = []

  init(maxCount: Int, quality: PersonSegmentationProcessor.Quality) {
    for _ in 0..<maxCount {
      available.append(PersonSegmentationProcessor(quality: quality))
    }
  }

  func process(
    webcamBuffer: CVPixelBuffer,
    style: CameraBackgroundStyle,
    backgroundCGImage: CGImage?
  ) -> CGImage? {
    condition.lock()
    while available.isEmpty {
      condition.wait()
    }
    let processor = available.removeLast()
    condition.unlock()

    defer {
      condition.lock()
      available.append(processor)
      condition.signal()
      condition.unlock()
    }

    return processor.processFrame(
      webcamBuffer: webcamBuffer,
      style: style,
      backgroundCGImage: backgroundCGImage
    )
  }
}

final class PersonSegmentationProcessor: @unchecked Sendable {
  enum Quality {
    case fast
    case balanced
    case accurate
  }

  private let quality: Quality
  private let ciContext: CIContext

  init(quality: Quality = .fast) {
    self.quality = quality
    self.ciContext = CIContext(options: [
      .useSoftwareRenderer: false,
      .cacheIntermediates: false
    ])
  }

  func generateMask(from pixelBuffer: CVPixelBuffer) -> CIImage? {
    let request = VNGeneratePersonSegmentationRequest()
    switch quality {
    case .fast: request.qualityLevel = .fast
    case .balanced: request.qualityLevel = .balanced
    case .accurate: request.qualityLevel = .accurate
    }
    request.outputPixelFormat = kCVPixelFormatType_OneComponent8

    let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

    do {
      try requestHandler.perform([request])
    } catch {
      return nil
    }

    guard let result = request.results?.first else { return nil }
    return CIImage(cvPixelBuffer: result.pixelBuffer)
  }

  func applyBackground(
    frame: CIImage,
    mask: CIImage,
    style: CameraBackgroundStyle,
    gradientPresetId: Int? = nil,
    backgroundCGImage: CGImage? = nil
  ) -> CIImage {
    let extent = frame.extent
    let scaledMask = mask.transformed(
      by: CGAffineTransform(
        scaleX: extent.width / mask.extent.width,
        y: extent.height / mask.extent.height
      )
    )
    .applyingGaussianBlur(sigma: 2.0)
    .cropped(to: extent)

    let backgroundImage: CIImage
    switch style {
    case .none:
      return frame
    case .blur(let intensity):
      let radius = intensity * 30.0
      backgroundImage = frame.clampedToExtent()
        .applyingGaussianBlur(sigma: Double(radius))
        .cropped(to: extent)
    case .solidColor(let color):
      let ciColor = CIColor(red: color.r, green: color.g, blue: color.b, alpha: color.a)
      backgroundImage = CIImage(color: ciColor).cropped(to: extent)
    case .gradient(let id):
      backgroundImage = renderGradient(presetId: id, size: extent.size)
    case .image:
      if let cgImage = backgroundCGImage {
        backgroundImage = fillImage(CIImage(cgImage: cgImage), into: extent)
      } else {
        return frame
      }
    }

    guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return frame }
    blendFilter.setValue(frame, forKey: kCIInputImageKey)
    blendFilter.setValue(backgroundImage, forKey: kCIInputBackgroundImageKey)
    blendFilter.setValue(scaledMask, forKey: kCIInputMaskImageKey)
    return blendFilter.outputImage ?? frame
  }

  func processFrame(
    webcamBuffer: CVPixelBuffer,
    style: CameraBackgroundStyle,
    backgroundCGImage: CGImage? = nil
  ) -> CGImage? {
    guard style != .none else { return nil }
    let frame = CIImage(cvPixelBuffer: webcamBuffer)
    guard let mask = generateMask(from: webcamBuffer) else { return nil }
    let composited = applyBackground(
      frame: frame,
      mask: mask,
      style: style,
      backgroundCGImage: backgroundCGImage
    )
    let extent = composited.extent
    return ciContext.createCGImage(composited, from: extent)
  }

  private func renderGradient(presetId: Int, size: CGSize) -> CIImage {
    guard let preset = GradientPresets.preset(for: presetId),
      !preset.cgColors.isEmpty
    else {
      return CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: size))
    }

    let width = Int(size.width)
    let height = Int(size.height)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard
      let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else {
      return CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: size))
    }

    let colors = preset.cgColors as CFArray
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: nil) else {
      return CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: size))
    }

    let startPoint = CGPoint(x: preset.cgStartPoint.x * size.width, y: preset.cgStartPoint.y * size.height)
    let endPoint = CGPoint(x: preset.cgEndPoint.x * size.width, y: preset.cgEndPoint.y * size.height)
    ctx.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    guard let cgImage = ctx.makeImage() else {
      return CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: size))
    }
    return CIImage(cgImage: cgImage)
  }

  private func fillImage(_ image: CIImage, into extent: CGRect) -> CIImage {
    let imgExtent = image.extent
    let scaleX = extent.width / max(imgExtent.width, 1)
    let scaleY = extent.height / max(imgExtent.height, 1)
    let scale = max(scaleX, scaleY)
    let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let dx = (extent.width - scaled.extent.width) / 2
    let dy = (extent.height - scaled.extent.height) / 2
    return scaled.transformed(by: CGAffineTransform(translationX: dx - scaled.extent.origin.x, y: dy - scaled.extent.origin.y))
      .cropped(to: extent)
  }
}
