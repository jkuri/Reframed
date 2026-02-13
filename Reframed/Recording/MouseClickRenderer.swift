import AppKit
import CoreGraphics
import CoreMedia
import CoreVideo

final class MouseClickRenderer: @unchecked Sendable {
  private struct Click {
    let bufferPoint: CGPoint
    let time: CMTime
  }

  private let lock = NSLock()
  private var clicks: [Click] = []
  private var captureOriginX: CGFloat = 0
  private var captureOriginY: CGFloat = 0
  private var scale: CGFloat = 2.0
  private var screenHeight: CGFloat = 0
  private var isConfigured = false

  private let colorR: CGFloat
  private let colorG: CGFloat
  private let colorB: CGFloat
  private let size: CGFloat
  private static let animationDuration: Double = 0.4

  init(color: NSColor, size: CGFloat) {
    let c = color.usingColorSpace(.sRGB) ?? color
    colorR = c.redComponent
    colorG = c.greenComponent
    colorB = c.blueComponent
    self.size = size
  }

  func configure(captureOrigin: CGPoint, displayScale: CGFloat, displayHeight: CGFloat) {
    lock.lock()
    captureOriginX = captureOrigin.x
    captureOriginY = captureOrigin.y
    scale = displayScale
    screenHeight = displayHeight
    isConfigured = true
    lock.unlock()
  }

  func recordClick(at screenPoint: CGPoint) {
    let hostTime = CMClockGetTime(CMClockGetHostTimeClock())
    lock.lock()
    guard isConfigured else {
      lock.unlock()
      return
    }
    let sckX = screenPoint.x
    let sckY = screenHeight - screenPoint.y
    let bufX = (sckX - captureOriginX) * scale
    let bufY = (sckY - captureOriginY) * scale
    clicks.append(Click(bufferPoint: CGPoint(x: bufX, y: bufY), time: hostTime))
    lock.unlock()
  }

  func processFrame(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
    let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

    lock.lock()
    clicks.removeAll { CMTimeGetSeconds(CMTimeSubtract(pts, $0.time)) > Self.animationDuration }

    guard !clicks.isEmpty else {
      lock.unlock()
      return nil
    }

    let scaleFactor = scale
    let activeClicks = clicks.map { click -> (point: CGPoint, progress: Double) in
      let elapsed = CMTimeGetSeconds(CMTimeSubtract(pts, click.time))
      let progress = min(max(elapsed / Self.animationDuration, 0), 1)
      return (click.bufferPoint, progress)
    }
    lock.unlock()

    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let srcBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

    guard pixelFormat == kCVPixelFormatType_32BGRA else { return nil }
    guard let srcBase = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

    var newBuffer: CVPixelBuffer?
    let attrs: [String: Any] = [
      kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
    ]
    let createStatus = CVPixelBufferCreate(
      kCFAllocatorDefault,
      width,
      height,
      pixelFormat,
      attrs as CFDictionary,
      &newBuffer
    )
    guard createStatus == kCVReturnSuccess, let destBuffer = newBuffer else { return nil }

    CVPixelBufferLockBaseAddress(destBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(destBuffer, []) }

    guard let dstBase = CVPixelBufferGetBaseAddress(destBuffer) else { return nil }
    let dstBytesPerRow = CVPixelBufferGetBytesPerRow(destBuffer)

    if srcBytesPerRow == dstBytesPerRow {
      memcpy(dstBase, srcBase, srcBytesPerRow * height)
    } else {
      for row in 0..<height {
        memcpy(
          dstBase.advanced(by: row * dstBytesPerRow),
          srcBase.advanced(by: row * srcBytesPerRow),
          min(srcBytesPerRow, dstBytesPerRow)
        )
      }
    }

    let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue

    guard
      let context = CGContext(
        data: dstBase,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: dstBytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: bitmapInfo
      )
    else { return nil }

    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)

    let scaledSize = size * scaleFactor

    for (point, progress) in activeClicks {
      let startDiameter = scaledSize * 0.44
      let endDiameter = scaledSize
      let currentDiameter = startDiameter + (endDiameter - startDiameter) * CGFloat(progress)
      let opacity = CGFloat(1.0 - progress)

      let radius = currentDiameter / 2
      let circleRect = CGRect(
        x: point.x - radius,
        y: point.y - radius,
        width: currentDiameter,
        height: currentDiameter
      )

      context.setFillColor(
        CGColor(
          srgbRed: colorR,
          green: colorG,
          blue: colorB,
          alpha: 0.3 * opacity
        )
      )
      context.fillEllipse(in: circleRect)

      context.setStrokeColor(
        CGColor(
          srgbRed: colorR,
          green: colorG,
          blue: colorB,
          alpha: opacity
        )
      )
      context.setLineWidth(2.0 * scaleFactor)
      context.strokeEllipse(in: circleRect)
    }

    var timingInfo = CMSampleTimingInfo(
      duration: CMSampleBufferGetDuration(sampleBuffer),
      presentationTimeStamp: pts,
      decodeTimeStamp: .invalid
    )
    var videoInfo: CMVideoFormatDescription?
    CMVideoFormatDescriptionCreateForImageBuffer(
      allocator: kCFAllocatorDefault,
      imageBuffer: destBuffer,
      formatDescriptionOut: &videoInfo
    )
    guard let formatDesc = videoInfo else { return nil }

    var newSampleBuffer: CMSampleBuffer?
    CMSampleBufferCreateReadyWithImageBuffer(
      allocator: kCFAllocatorDefault,
      imageBuffer: destBuffer,
      formatDescription: formatDesc,
      sampleTiming: &timingInfo,
      sampleBufferOut: &newSampleBuffer
    )

    return newSampleBuffer
  }
}
