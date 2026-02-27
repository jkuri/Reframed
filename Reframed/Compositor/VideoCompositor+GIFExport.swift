import AVFoundation
import CoreMedia
import Foundation
import gifski

extension VideoCompositor {
  static func gifExport(
    composition: AVComposition,
    instruction: CompositionInstruction,
    renderSize: CGSize,
    fps: Int,
    trimDuration: CMTime,
    outputURL: URL,
    gifQuality: UInt8 = 90,
    progressHandler: (@MainActor @Sendable (Double, Double?) -> Void)?
  ) async throws {
    let reader = try AVAssetReader(asset: composition)
    reader.timeRange = CMTimeRange(start: .zero, duration: trimDuration)

    guard
      let screenTrack = composition.tracks(withMediaType: .video)
        .first(where: { $0.trackID == instruction.screenTrackID })
    else {
      throw CaptureError.recordingFailed("No screen track found")
    }

    let screenOutput = AVAssetReaderTrackOutput(
      track: screenTrack,
      outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    )
    screenOutput.alwaysCopiesSampleData = false
    reader.add(screenOutput)

    var webcamOutput: AVAssetReaderTrackOutput?
    if let webcamTrackID = instruction.webcamTrackID,
      let webcamTrack = composition.tracks(withMediaType: .video)
        .first(where: { $0.trackID == webcamTrackID })
    {
      let output = AVAssetReaderTrackOutput(
        track: webcamTrack,
        outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
      )
      output.alwaysCopiesSampleData = false
      reader.add(output)
      webcamOutput = output
    }

    reader.startReading()

    let totalFrames = Int(ceil(CMTimeGetSeconds(trimDuration) * Double(fps)))
    let timescale = CMTimeScale(fps)

    let width = UInt32(renderSize.width)
    let height = UInt32(renderSize.height)

    var settings = GifskiSettings(
      width: width,
      height: height,
      quality: gifQuality,
      fast: false,
      repeat: 0
    )

    guard let g = gifski_new(&settings) else {
      throw CaptureError.recordingFailed("Failed to create gifski encoder")
    }

    let result = gifski_set_file_output(g, outputURL.path.cString(using: .utf8))
    guard result == GIFSKI_OK else {
      gifski_finish(g)
      throw CaptureError.recordingFailed("Failed to set gifski output file")
    }

    nonisolated(unsafe) let pipelineReader = reader
    nonisolated(unsafe) let pipelineScreenOutput = screenOutput
    nonisolated(unsafe) let pipelineWebcamOutput = webcamOutput
    nonisolated(unsafe) let pipelineGifski = g

    nonisolated(unsafe) let cancelled = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
    cancelled.initialize(to: false)
    defer { cancelled.deallocate() }

    let gifSegProcessor =
      instruction.cameraBackgroundStyle != .none
      ? PersonSegmentationProcessor(quality: .balanced)
      : nil
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
        DispatchQueue.global(qos: .userInitiated).async {
          var latestScreenSample: CMSampleBuffer?
          var nextScreenSample: CMSampleBuffer? = pipelineScreenOutput.copyNextSampleBuffer()
          var latestWebcamSample: CMSampleBuffer?
          var nextWebcamSample: CMSampleBuffer? = pipelineWebcamOutput?.copyNextSampleBuffer()

          let exportStartTime = CFAbsoluteTimeGetCurrent()

          var outputPool: CVPixelBufferPool?
          let poolAttrs: NSDictionary = [kCVPixelBufferPoolMinimumBufferCountKey: 2]
          let pbAttrs: NSDictionary = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: Int(width),
            kCVPixelBufferHeightKey: Int(height),
          ]
          CVPixelBufferPoolCreate(nil, poolAttrs, pbAttrs, &outputPool)
          guard let pool = outputPool else {
            gifski_finish(pipelineGifski)
            cont.resume(
              throwing: CaptureError.recordingFailed("Failed to create pixel buffer pool for GIF")
            )
            return
          }

          let rgbaBuffer = UnsafeMutablePointer<UInt8>.allocate(
            capacity: Int(width) * Int(height) * 4
          )
          defer { rgbaBuffer.deallocate() }

          for frameIndex in 0..<totalFrames {
            if cancelled.pointee {
              pipelineReader.cancelReading()
              gifski_finish(pipelineGifski)
              try? FileManager.default.removeItem(at: outputURL)
              cont.resume(throwing: CancellationError())
              return
            }

            let outputTime = CMTime(value: CMTimeValue(frameIndex), timescale: timescale)
            let outputSeconds = CMTimeGetSeconds(outputTime)

            while let next = nextScreenSample {
              if CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(next))
                <= outputSeconds + 0.001
              {
                latestScreenSample = next
                nextScreenSample = pipelineScreenOutput.copyNextSampleBuffer()
              } else {
                break
              }
            }

            if pipelineWebcamOutput != nil {
              while let next = nextWebcamSample {
                if CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(next))
                  <= outputSeconds + 0.001
                {
                  latestWebcamSample = next
                  nextWebcamSample = pipelineWebcamOutput!.copyNextSampleBuffer()
                } else {
                  break
                }
              }
            }

            guard let screenSample = latestScreenSample,
              let screenBuffer = CMSampleBufferGetImageBuffer(screenSample)
            else { continue }

            let webcamBuffer = latestWebcamSample.flatMap { CMSampleBufferGetImageBuffer($0) }

            var processedWebcam: CGImage?
            if let wb = webcamBuffer, let proc = gifSegProcessor {
              processedWebcam = proc.processFrame(
                webcamBuffer: wb,
                style: instruction.cameraBackgroundStyle,
                backgroundCGImage: instruction.cameraBackgroundImage
              )
            }

            var outBuf: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &outBuf)
            guard let outputBuffer = outBuf else { continue }

            CameraVideoCompositor.renderFrame(
              screenBuffer: screenBuffer,
              webcamBuffer: webcamBuffer,
              outputBuffer: outputBuffer,
              compositionTime: outputTime,
              instruction: instruction,
              processedWebcamImage: processedWebcam
            )

            CVPixelBufferLockBaseAddress(outputBuffer, .readOnly)
            let baseAddress = CVPixelBufferGetBaseAddress(outputBuffer)!
            let bytesPerRow = CVPixelBufferGetBytesPerRow(outputBuffer)
            let src = baseAddress.assumingMemoryBound(to: UInt8.self)

            for y in 0..<Int(height) {
              let srcRow = src + y * bytesPerRow
              let dstRow = rgbaBuffer + y * Int(width) * 4
              for x in 0..<Int(width) {
                let srcPixel = srcRow + x * 4
                let dstPixel = dstRow + x * 4
                dstPixel[0] = srcPixel[2]
                dstPixel[1] = srcPixel[1]
                dstPixel[2] = srcPixel[0]
                dstPixel[3] = srcPixel[3]
              }
            }

            CVPixelBufferUnlockBaseAddress(outputBuffer, .readOnly)

            let pts = Double(frameIndex) / Double(fps)
            let addResult = gifski_add_frame_rgba(
              pipelineGifski,
              UInt32(frameIndex),
              width,
              height,
              rgbaBuffer,
              pts
            )

            if addResult != GIFSKI_OK {
              pipelineReader.cancelReading()
              gifski_finish(pipelineGifski)
              cont.resume(
                throwing: CaptureError.recordingFailed("gifski_add_frame failed: \(addResult)")
              )
              return
            }

            if frameIndex % 10 == 0 || frameIndex == totalFrames - 1 {
              let progress = Double(frameIndex + 1) / Double(totalFrames)
              let elapsed = CFAbsoluteTimeGetCurrent() - exportStartTime
              let remaining = Double(totalFrames - frameIndex - 1)
              let secsPerFrame = elapsed / Double(frameIndex + 1)
              let eta = remaining * secsPerFrame
              if let handler = progressHandler {
                Task { @MainActor in handler(min(progress, 0.99), eta) }
              }
            }
          }

          pipelineReader.cancelReading()

          if cancelled.pointee {
            gifski_finish(pipelineGifski)
            try? FileManager.default.removeItem(at: outputURL)
            cont.resume(throwing: CancellationError())
            return
          }

          let finishResult = gifski_finish(pipelineGifski)
          if finishResult != GIFSKI_OK {
            cont.resume(
              throwing: CaptureError.recordingFailed("gifski_finish failed: \(finishResult)")
            )
            return
          }

          if let handler = progressHandler {
            Task { @MainActor in handler(1.0, nil) }
          }
          cont.resume()
        }
      }
    } onCancel: {
      cancelled.pointee = true
    }
  }
}
