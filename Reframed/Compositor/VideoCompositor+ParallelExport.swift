import AVFoundation
import CoreMedia
import Foundation
import Logging
import VideoToolbox

extension VideoCompositor {
  private final class CancelToken: @unchecked Sendable {
    private let lock = NSLock()
    private var _isCancelled = false
    var isCancelled: Bool {
      lock.lock()
      defer { lock.unlock() }
      return _isCancelled
    }
    func cancel() {
      lock.lock()
      _isCancelled = true
      lock.unlock()
    }
  }

  private final class SafeContinuation: @unchecked Sendable {
    private let lock = NSLock()
    private var cont: CheckedContinuation<Void, any Error>?

    init(_ cont: CheckedContinuation<Void, any Error>) {
      self.cont = cont
    }

    func resume() {
      lock.lock()
      let c = cont
      cont = nil
      lock.unlock()
      c?.resume()
    }

    func resume(throwing error: any Error) {
      lock.lock()
      let c = cont
      cont = nil
      lock.unlock()
      c?.resume(throwing: error)
    }
  }

  private final class OrderedFrameWriter: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [Int: (CVPixelBuffer, CMTime)] = [:]
    private var nextIndex = 0
    private var draining = false
    private var isCancelled = false
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let input: AVAssetWriterInput
    private var finished = false
    private var hasSignaled = false
    private let doneSignal = DispatchSemaphore(value: 0)

    private let totalFrames: Int
    private let progressHandler: (@MainActor @Sendable (Double, Double?) -> Void)?
    private let startTime: CFAbsoluteTime
    private let backpressure: DispatchSemaphore

    init(
      adaptor: AVAssetWriterInputPixelBufferAdaptor,
      input: AVAssetWriterInput,
      totalFrames: Int,
      progressHandler: (@MainActor @Sendable (Double, Double?) -> Void)?,
      backpressure: DispatchSemaphore
    ) {
      self.adaptor = adaptor
      self.input = input
      self.totalFrames = totalFrames
      self.progressHandler = progressHandler
      self.startTime = CFAbsoluteTimeGetCurrent()
      self.backpressure = backpressure
    }

    func start() {
      input.requestMediaDataWhenReady(
        on: DispatchQueue(label: "eu.jankuri.reframed.video-writer", qos: .userInteractive)
      ) { [weak self] in
        self?.drain()
      }
    }

    func submit(index: Int, buffer: CVPixelBuffer, time: CMTime) {
      lock.lock()
      if isCancelled {
        lock.unlock()
        backpressure.signal()
        return
      }
      pending[index] = (buffer, time)
      lock.unlock()
      drain()
    }

    func finish() {
      lock.lock()
      finished = true
      lock.unlock()
      drain()
    }

    func cancel() {
      lock.lock()
      isCancelled = true
      let pendingCount = pending.count
      pending.removeAll()
      finished = true
      let shouldSignalDone = !hasSignaled
      if shouldSignalDone { hasSignaled = true }
      draining = false
      lock.unlock()

      for _ in 0..<pendingCount {
        backpressure.signal()
      }

      if shouldSignalDone {
        doneSignal.signal()
      }
    }

    func waitUntilDone() {
      doneSignal.wait()
    }

    private func drain() {
      lock.lock()
      if draining || isCancelled {
        lock.unlock()
        return
      }
      draining = true

      while !isCancelled && input.isReadyForMoreMediaData {
        guard let (buf, time) = pending[nextIndex] else { break }
        pending.removeValue(forKey: nextIndex)
        nextIndex += 1
        let writtenCount = nextIndex
        lock.unlock()

        adaptor.append(buf, withPresentationTime: time)
        backpressure.signal()

        if writtenCount % 30 == 0 || writtenCount == totalFrames {
          let progress = (Double(writtenCount) / Double(max(totalFrames, 1))) * 0.99
          let elapsed = CFAbsoluteTimeGetCurrent() - startTime
          let remaining = Double(totalFrames - writtenCount)
          let secsPerFrame = elapsed / Double(writtenCount)
          let eta = remaining * secsPerFrame
          if let handler = progressHandler {
            Task { @MainActor in handler(progress, eta) }
          }
        }

        lock.lock()
      }

      let shouldSignalDone = finished && pending.isEmpty && !hasSignaled && !isCancelled
      if shouldSignalDone { hasSignaled = true }
      draining = false
      lock.unlock()

      if shouldSignalDone {
        doneSignal.signal()
      }
    }
  }

  static func parallelRenderExport(
    composition: AVComposition,
    instruction: CompositionInstruction,
    renderSize: CGSize,
    fps: Int,
    trimDuration: CMTime,
    outputURL: URL,
    fileType: AVFileType,
    codec: ExportCodec,
    audioMix: AVAudioMix? = nil,
    audioBitrate: Int = 320_000,
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
      outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_64RGBAHalf]
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
        outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_64RGBAHalf]
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

    let videoCodec: AVVideoCodecType = codec.videoCodecType
    let parallelColorProperties: [String: Any] = [
      AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
      AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
      AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
    ]
    let videoOutputSettings: [String: Any]
    if codec.isProRes {
      videoOutputSettings = [
        AVVideoCodecKey: videoCodec,
        AVVideoWidthKey: Int(renderSize.width),
        AVVideoHeightKey: Int(renderSize.height),
        AVVideoColorPropertiesKey: parallelColorProperties,
      ]
    } else {
      let pixels = Double(renderSize.width * renderSize.height)
      var compressionProperties: [String: Any] = [
        AVVideoExpectedSourceFrameRateKey: fps,
        AVVideoMaxKeyFrameIntervalKey: fps,
      ]
      if codec == .h265 {
        compressionProperties[AVVideoAverageBitRateKey] = pixels * 5
        compressionProperties[AVVideoProfileLevelKey] = kVTProfileLevel_HEVC_Main10_AutoLevel
      } else {
        compressionProperties[AVVideoAverageBitRateKey] = pixels * 7
        compressionProperties[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
      }
      videoOutputSettings = [
        AVVideoCodecKey: videoCodec,
        AVVideoWidthKey: Int(renderSize.width),
        AVVideoHeightKey: Int(renderSize.height),
        AVVideoColorPropertiesKey: parallelColorProperties,
        AVVideoCompressionPropertiesKey: compressionProperties,
      ]
    }
    let videoInput = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: videoOutputSettings
    )
    videoInput.expectsMediaDataInRealTime = false

    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: videoInput,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_64RGBAHalf,
        kCVPixelBufferWidthKey as String: Int(renderSize.width),
        kCVPixelBufferHeightKey as String: Int(renderSize.height),
      ]
    )
    assetWriter.add(videoInput)

    var audioWriterInput: AVAssetWriterInput?
    if !audioTracks.isEmpty {
      let aInput = AVAssetWriterInput(
        mediaType: .audio,
        outputSettings: [
          AVFormatIDKey: kAudioFormatMPEG4AAC,
          AVNumberOfChannelsKey: 2,
          AVSampleRateKey: 44100,
          AVEncoderBitRateKey: audioBitrate,
        ]
      )
      aInput.expectsMediaDataInRealTime = false
      assetWriter.add(aInput)
      audioWriterInput = aInput
    }

    reader.startReading()
    audioReader?.startReading()
    assetWriter.startWriting()
    assetWriter.startSession(atSourceTime: .zero)

    let coreCount = ProcessInfo.processInfo.activeProcessorCount

    let bytesPerFrame = Int(renderSize.width) * Int(renderSize.height) * 8
    let maxMemoryBytes = 1_500_000_000
    let maxInFlight = max(coreCount * 4, min(maxMemoryBytes / max(bytesPerFrame, 1), 120))

    var poolRef: CVPixelBufferPool?
    let poolAttrs: NSDictionary = [kCVPixelBufferPoolMinimumBufferCountKey: maxInFlight + 4]
    let pbAttrs: NSDictionary = [
      kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_64RGBAHalf,
      kCVPixelBufferWidthKey: Int(renderSize.width),
      kCVPixelBufferHeightKey: Int(renderSize.height),
    ]
    CVPixelBufferPoolCreate(nil, poolAttrs, pbAttrs, &poolRef)
    guard let outputPool = poolRef else {
      throw CaptureError.recordingFailed("Failed to create pixel buffer pool")
    }

    let totalFrames = Int(ceil(CMTimeGetSeconds(trimDuration) * Double(fps)))
    let timescale = CMTimeScale(fps)

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

    let cancelToken = CancelToken()
    let sem = DispatchSemaphore(value: maxInFlight)

    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
        let safeCont = SafeContinuation(cont)

        DispatchQueue.global(qos: .userInitiated).async {
          let audioGroup = DispatchGroup()

          final class AudioState: @unchecked Sendable {
            var finished = false
            let lock = NSLock()
          }
          let audioState = AudioState()

          if let aOut = pipelineAudioOutput, let aIn = pipelineAudioWriterInput,
            pipelineAudioReader?.status == .reading
          {
            nonisolated(unsafe) let safeAudioOutput = aOut
            nonisolated(unsafe) let safeAudioInput = aIn
            audioGroup.enter()
            let audioQueue = DispatchQueue(label: "eu.jankuri.reframed.audio", qos: .userInitiated)
            safeAudioInput.requestMediaDataWhenReady(on: audioQueue) {
              while safeAudioInput.isReadyForMoreMediaData {
                audioState.lock.lock()
                if audioState.finished { audioState.lock.unlock(); break }
                audioState.lock.unlock()

                if cancelToken.isCancelled {
                  safeAudioInput.markAsFinished()
                  audioState.lock.lock()
                  if !audioState.finished { audioState.finished = true; audioGroup.leave() }
                  audioState.lock.unlock()
                  break
                }
                if let sample = safeAudioOutput.copyNextSampleBuffer() {
                  safeAudioInput.append(sample)
                } else {
                  safeAudioInput.markAsFinished()
                  audioState.lock.lock()
                  if !audioState.finished { audioState.finished = true; audioGroup.leave() }
                  audioState.lock.unlock()
                  break
                }
              }
            }
          } else {
            pipelineAudioWriterInput?.markAsFinished()
          }

          let frameWriter = OrderedFrameWriter(
            adaptor: pipelineAdaptor,
            input: pipelineVideoInput,
            totalFrames: totalFrames,
            progressHandler: progressHandler,
            backpressure: sem
          )
          frameWriter.start()

          let renderQueue = DispatchQueue(
            label: "eu.jankuri.reframed.render",
            qos: .userInitiated,
            attributes: .concurrent
          )
          let renderGroup = DispatchGroup()

          var latestScreenSample: CMSampleBuffer?
          var nextScreenSample: CMSampleBuffer? = pipelineScreenOutput.copyNextSampleBuffer()
          var latestWebcamSample: CMSampleBuffer?
          var nextWebcamSample: CMSampleBuffer? = pipelineWebcamOutput?.copyNextSampleBuffer()

          for frameIndex in 0..<totalFrames {
            if cancelToken.isCancelled { break }

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

            guard let screenBuffer = latestScreenSample.flatMap({ CMSampleBufferGetImageBuffer($0) })
            else { continue }
            let webcamBuffer = latestWebcamSample.flatMap { CMSampleBufferGetImageBuffer($0) }

            sem.wait()
            if cancelToken.isCancelled { sem.signal(); break }

            var outBuf: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pipelineOutputPool, &outBuf)
            guard let outputBuffer = outBuf else {
              sem.signal()
              continue
            }

            nonisolated(unsafe) let capturedScreen = screenBuffer
            nonisolated(unsafe) let capturedWebcam = webcamBuffer
            nonisolated(unsafe) let capturedOutput = outputBuffer

            renderGroup.enter()
            renderQueue.async {
              autoreleasepool {
                CameraVideoCompositor.renderFrame(
                  screenBuffer: capturedScreen,
                  webcamBuffer: capturedWebcam,
                  outputBuffer: capturedOutput,
                  compositionTime: outputTime,
                  instruction: instruction
                )
                frameWriter.submit(index: frameIndex, buffer: capturedOutput, time: outputTime)
              }
              renderGroup.leave()
            }
          }

          latestScreenSample = nil
          nextScreenSample = nil
          latestWebcamSample = nil
          nextWebcamSample = nil

          renderGroup.wait()

          if cancelToken.isCancelled {
            frameWriter.cancel()
            pipelineAudioReader?.cancelReading()
            pipelineReader.cancelReading()
            pipelineWriter.cancelWriting()
            CVPixelBufferPoolFlush(pipelineOutputPool, CVPixelBufferPoolFlushFlags(rawValue: 1))
            try? FileManager.default.removeItem(at: outputURL)
            safeCont.resume(throwing: CancellationError())
            return
          }

          frameWriter.finish()
          frameWriter.waitUntilDone()

          pipelineVideoInput.markAsFinished()
          pipelineReader.cancelReading()

          audioGroup.wait()

          if cancelToken.isCancelled {
            pipelineWriter.cancelWriting()
            CVPixelBufferPoolFlush(pipelineOutputPool, CVPixelBufferPoolFlushFlags(rawValue: 1))
            try? FileManager.default.removeItem(at: outputURL)
            safeCont.resume(throwing: CancellationError())
            return
          }

          pipelineWriter.finishWriting {
            CVPixelBufferPoolFlush(pipelineOutputPool, CVPixelBufferPoolFlushFlags(rawValue: 1))
            if pipelineWriter.status == .failed {
              safeCont.resume(
                throwing: pipelineWriter.error
                  ?? CaptureError.recordingFailed("Export writing failed")
              )
            } else {
              logger.info("Parallel render export completed (\(coreCount) cores)")
              if let handler = progressHandler {
                Task { @MainActor in handler(1.0, nil) }
              }
              safeCont.resume()
            }
          }
        }
      }
    } onCancel: {
      cancelToken.cancel()
      sem.signal()
    }
  }
}
