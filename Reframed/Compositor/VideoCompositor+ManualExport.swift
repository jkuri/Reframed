import AVFoundation
import CoreMedia
import Foundation
import Logging

extension VideoCompositor {
  private final class ExportProgressPoller: @unchecked Sendable {
    private let session: AVAssetExportSession
    init(_ session: AVAssetExportSession) { self.session = session }
    var progress: Double { Double(session.progress) }
  }

  static func runExport(
    _ session: AVAssetExportSession,
    to url: URL,
    fileType: AVFileType = .mp4,
    progressHandler: (@MainActor @Sendable (Double, Double?) -> Void)?
  ) async throws {
    let progressTask: Task<Void, Never>?
    if let progressHandler {
      let poller = ExportProgressPoller(session)
      progressTask = Task.detached {
        while !Task.isCancelled {
          await progressHandler(poller.progress, nil)
          try? await Task.sleep(nanoseconds: 200_000_000)
        }
      }
    } else {
      progressTask = nil
    }
    nonisolated(unsafe) let session = session
    try await withTaskCancellationHandler {
      try await session.export(to: url, as: fileType)
    } onCancel: {
      session.cancelExport()
    }
    progressTask?.cancel()
  }

  static func runManualExport(
    composition: AVComposition,
    instruction: CompositionInstruction,
    renderSize: CGSize,
    fps: Int,
    trimDuration: CMTime,
    speed: Double = 1.0,
    outputURL: URL,
    fileType: AVFileType,
    codec: ExportCodec,
    audioMix: AVAudioMix? = nil,
    audioBitrate: Int = 320_000,
    isHDR: Bool = false,
    progressHandler: (@MainActor @Sendable (Double, Double?) -> Void)?
  ) async throws {
    let logger = Logger(label: "eu.jankuri.reframed.video-compositor")

    let reader = try AVAssetReader(asset: composition)
    reader.timeRange = CMTimeRange(start: .zero, duration: trimDuration)

    guard
      let screenTrack = composition.tracks(withMediaType: .video)
        .first(where: { $0.trackID == instruction.screenTrackID })
    else {
      throw CaptureError.recordingFailed("No screen track found")
    }

    let pixelFormat = kCVPixelFormatType_64RGBAHalf

    let screenOutput = AVAssetReaderTrackOutput(
      track: screenTrack,
      outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: pixelFormat]
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
        outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: pixelFormat]
      )
      output.alwaysCopiesSampleData = false
      reader.add(output)
      webcamOutput = output
    }

    let audioTracks = composition.tracks(withMediaType: .audio)

    var audioReader: AVAssetReader?
    var audioOutput: AVAssetReaderAudioMixOutput?
    if !audioTracks.isEmpty {
      let aReader = try AVAssetReader(asset: composition)
      aReader.timeRange = CMTimeRange(start: .zero, duration: trimDuration)
      let mixOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)
      if let audioMix {
        mixOutput.audioMix = audioMix
      }
      mixOutput.alwaysCopiesSampleData = false
      aReader.add(mixOutput)
      audioOutput = mixOutput
      audioReader = aReader
    }

    let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: fileType)

    let videoOutputSettings = EncodingSettings.exportVideoSettings(
      codec: codec.videoCodecType,
      width: Int(renderSize.width),
      height: Int(renderSize.height),
      fps: fps,
      isHDR: isHDR
    )

    let videoInput = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: videoOutputSettings
    )
    videoInput.expectsMediaDataInRealTime = false
    assetWriter.add(videoInput)

    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: videoInput,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
        kCVPixelBufferWidthKey as String: Int(renderSize.width),
        kCVPixelBufferHeightKey as String: Int(renderSize.height),
        kCVPixelBufferIOSurfacePropertiesKey as String: [:] as NSDictionary,
      ]
    )

    var audioWriterInput: AVAssetWriterInput?
    if !audioTracks.isEmpty {
      let aInput = AVAssetWriterInput(
        mediaType: .audio,
        outputSettings: EncodingSettings.aacAudioSettings(bitrate: audioBitrate)
      )
      aInput.expectsMediaDataInRealTime = false
      assetWriter.add(aInput)
      audioWriterInput = aInput
    }

    guard reader.startReading() else {
      throw reader.error ?? CaptureError.recordingFailed("Failed to start video reader")
    }

    if let audioReader {
      guard audioReader.startReading() else {
        throw audioReader.error ?? CaptureError.recordingFailed("Failed to start audio reader")
      }
    }

    guard assetWriter.startWriting() else {
      throw assetWriter.error ?? CaptureError.recordingFailed("Failed to start writing")
    }
    assetWriter.startSession(atSourceTime: .zero)

    var poolRef: CVPixelBufferPool?
    let poolAttrs: NSDictionary = [kCVPixelBufferPoolMinimumBufferCountKey: 4]
    let pbAttrs: NSDictionary = [
      kCVPixelBufferPixelFormatTypeKey: pixelFormat,
      kCVPixelBufferWidthKey: Int(renderSize.width),
      kCVPixelBufferHeightKey: Int(renderSize.height),
      kCVPixelBufferIOSurfacePropertiesKey: [:] as NSDictionary,
    ]
    CVPixelBufferPoolCreate(nil, poolAttrs, pbAttrs, &poolRef)
    guard let outputPool = poolRef else {
      throw CaptureError.recordingFailed("Failed to create pixel buffer pool")
    }

    let totalFrames = TimeLapse.frameCount(duration: trimDuration, fps: fps, speed: speed)
    let timescale = CMTimeScale(fps)
    let exportStart = CFAbsoluteTimeGetCurrent()

    let hasCameraBg = instruction.cameraBackgroundStyle != .none
    let segProcessor = hasCameraBg ? PersonSegmentationProcessor(quality: .balanced) : nil

    nonisolated(unsafe) let pipelineReader = reader
    nonisolated(unsafe) let pipelineScreenOutput = screenOutput
    nonisolated(unsafe) let pipelineWebcamOutput = webcamOutput
    nonisolated(unsafe) let pipelineAudioReader = audioReader
    nonisolated(unsafe) let pipelineAudioOutput = audioOutput
    nonisolated(unsafe) let pipelineAudioWriterInput = audioWriterInput
    nonisolated(unsafe) let pipelineOutputPool = outputPool
    nonisolated(unsafe) let pipelineWriter = assetWriter
    nonisolated(unsafe) let pipelineVideoInput = videoInput
    nonisolated(unsafe) let pipelineAdaptor = adaptor
    let pipelineSegProcessor = segProcessor

    nonisolated(unsafe) let cancelled = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
    cancelled.initialize(to: false)
    defer { cancelled.deallocate() }

    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
        nonisolated(unsafe) var continued = false

        @Sendable func finish(_ result: Result<Void, Error>) {
          guard !continued else { return }
          continued = true
          switch result {
          case .success:
            cont.resume()
          case .failure(let error):
            cont.resume(throwing: error)
          }
        }

        DispatchQueue.global(qos: .userInitiated).async {
          let audioGroup = DispatchGroup()

          if let aOut = pipelineAudioOutput, let aIn = pipelineAudioWriterInput,
            pipelineAudioReader?.status == .reading
          {
            nonisolated(unsafe) let safeAudioOutput = aOut
            nonisolated(unsafe) let safeAudioInput = aIn
            audioGroup.enter()
            let audioQueue = DispatchQueue(label: "eu.jankuri.reframed.manual-audio", qos: .userInitiated)
            safeAudioInput.requestMediaDataWhenReady(on: audioQueue) {
              while safeAudioInput.isReadyForMoreMediaData {
                if cancelled.pointee {
                  safeAudioInput.markAsFinished()
                  audioGroup.leave()
                  return
                }
                if let sample = safeAudioOutput.copyNextSampleBuffer() {
                  _ = safeAudioInput.append(sample)
                } else {
                  safeAudioInput.markAsFinished()
                  audioGroup.leave()
                  return
                }
              }
            }
          } else {
            pipelineAudioWriterInput?.markAsFinished()
          }

          var latestScreenSample: CMSampleBuffer?
          var nextScreenSample: CMSampleBuffer? = pipelineScreenOutput.copyNextSampleBuffer()
          var latestWebcamSample: CMSampleBuffer?
          var nextWebcamSample: CMSampleBuffer? = pipelineWebcamOutput?.copyNextSampleBuffer()

          var framesWritten = 0

          for frameIndex in 0..<totalFrames {
            if cancelled.pointee { break }

            let outputTime = CMTime(value: CMTimeValue(frameIndex), timescale: timescale)
            let sourceTime = TimeLapse.sourceTime(forOutput: outputTime, speed: speed)
            let sourceSeconds = CMTimeGetSeconds(sourceTime)

            while let next = nextScreenSample {
              if CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(next)) <= sourceSeconds + 0.001 {
                latestScreenSample = next
                nextScreenSample = pipelineScreenOutput.copyNextSampleBuffer()
              } else {
                break
              }
            }

            if pipelineWebcamOutput != nil {
              while let next = nextWebcamSample {
                if CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(next)) <= sourceSeconds + 0.001 {
                  latestWebcamSample = next
                  nextWebcamSample = pipelineWebcamOutput?.copyNextSampleBuffer()
                } else {
                  break
                }
              }
            }

            guard let screenBuffer = latestScreenSample.flatMap({ CMSampleBufferGetImageBuffer($0) }) else {
              continue
            }

            let webcamBuffer = latestWebcamSample.flatMap { CMSampleBufferGetImageBuffer($0) }

            var outBuf: CVPixelBuffer?
            let poolStatus = CVPixelBufferPoolCreatePixelBuffer(nil, pipelineOutputPool, &outBuf)
            guard poolStatus == kCVReturnSuccess, let outputBuffer = outBuf else {
              continue
            }

            autoreleasepool {
              var processedWebcam: CGImage?
              if let wb = webcamBuffer, let seg = pipelineSegProcessor {
                CVPixelBufferLockBaseAddress(wb, .readOnly)
                processedWebcam = seg.processFrame(
                  webcamBuffer: wb,
                  style: instruction.cameraBackgroundStyle,
                  backgroundCGImage: instruction.cameraBackgroundImage
                )
                CVPixelBufferUnlockBaseAddress(wb, .readOnly)
              }

              FrameRenderer.renderFrame(
                screenBuffer: screenBuffer,
                webcamBuffer: webcamBuffer,
                outputBuffer: outputBuffer,
                compositionTime: sourceTime,
                instruction: instruction,
                processedWebcamImage: processedWebcam
              )
            }

            while !pipelineVideoInput.isReadyForMoreMediaData {
              if cancelled.pointee { break }
              Thread.sleep(forTimeInterval: 0.001)
            }

            if cancelled.pointee { break }

            pipelineAdaptor.append(outputBuffer, withPresentationTime: outputTime)
            framesWritten += 1

            if framesWritten % 10 == 0, let handler = progressHandler {
              let progress = min(Double(framesWritten) / Double(max(totalFrames, 1)), 0.99)
              let elapsed = CFAbsoluteTimeGetCurrent() - exportStart
              let remaining = Double(totalFrames - framesWritten)
              let secsPerFrame = elapsed / Double(max(framesWritten, 1))
              let eta = remaining * secsPerFrame
              Task { @MainActor in handler(progress, eta) }
            }
          }

          latestScreenSample = nil
          nextScreenSample = nil
          latestWebcamSample = nil
          nextWebcamSample = nil

          pipelineVideoInput.markAsFinished()
          pipelineReader.cancelReading()

          audioGroup.wait()

          if cancelled.pointee {
            pipelineAudioReader?.cancelReading()
            pipelineWriter.cancelWriting()
            CVPixelBufferPoolFlush(pipelineOutputPool, .excessBuffers)
            try? FileManager.default.removeItem(at: outputURL)
            finish(.failure(CancellationError()))
            return
          }

          let finalFrameCount = framesWritten
          pipelineWriter.finishWriting {
            CVPixelBufferPoolFlush(pipelineOutputPool, .excessBuffers)

            let exportEnd = CFAbsoluteTimeGetCurrent()
            logger.info(
              "Manual render export completed: \(finalFrameCount) frames in \(String(format: "%.3f", exportEnd - exportStart))s"
            )

            if pipelineWriter.status == .failed {
              finish(
                .failure(
                  pipelineWriter.error ?? CaptureError.recordingFailed("Export writing failed")
                )
              )
            } else {
              if let handler = progressHandler {
                Task { @MainActor in handler(1.0, nil) }
              }
              finish(.success(()))
            }
          }
        }
      }
    } onCancel: {
      cancelled.pointee = true
    }
  }
}
