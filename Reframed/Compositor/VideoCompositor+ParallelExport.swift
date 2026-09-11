import AVFoundation
import CoreMedia
import Foundation
import Logging
import os.lock

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

  private final class DoneCondition: @unchecked Sendable {
    private let condition = NSCondition()
    private var isDone = false

    func wait() {
      condition.lock()
      defer { condition.unlock() }
      while !isDone {
        condition.wait()
      }
    }

    func signal() {
      condition.lock()
      isDone = true
      condition.broadcast()
      condition.unlock()
    }
  }

  private final class CountingCondition: @unchecked Sendable {
    private let condition = NSCondition()
    private var count: Int

    init(value: Int) {
      self.count = value
    }

    func wait() {
      condition.lock()
      defer { condition.unlock() }
      while count <= 0 {
        condition.wait()
      }
      count -= 1
    }

    func signal() {
      condition.lock()
      count += 1
      condition.signal()
      condition.unlock()
    }

    func signal(times: Int) {
      guard times > 0 else { return }
      condition.lock()
      count += times
      for _ in 0..<times {
        condition.signal()
      }
      condition.unlock()
    }
  }

  private struct FrameJob: @unchecked Sendable {
    let index: Int
    let time: CMTime
    let sourceTime: CMTime
    let screenBuffer: CVPixelBuffer
    let webcamBuffer: CVPixelBuffer?
    let outputBuffer: CVPixelBuffer
    let style: CameraBackgroundStyle
    let backgroundImage: CGImage?
  }

  private final class FrameJobQueue: @unchecked Sendable {
    private let condition = NSCondition()
    private var storage: [FrameJob?] = []
    private var head = 0
    private var tail = 0
    private var count = 0
    private var isClosed = false

    init(initialCapacity: Int = 256) {
      let cap = max(16, initialCapacity.nextPowerOfTwo)
      storage = Array(repeating: nil, count: cap)
    }

    func push(_ job: FrameJob) {
      condition.lock()
      if count == storage.count {
        resize()
      }
      storage[tail] = job
      tail = (tail + 1) & (storage.count - 1)
      count += 1
      condition.signal()
      condition.unlock()
    }

    func pop() -> FrameJob? {
      condition.lock()
      defer { condition.unlock() }

      while count == 0 && !isClosed {
        condition.wait()
      }

      guard count > 0 else { return nil }

      let job = storage[head]
      storage[head] = nil
      head = (head + 1) & (storage.count - 1)
      count -= 1
      return job
    }

    func close() {
      condition.lock()
      isClosed = true
      condition.broadcast()
      condition.unlock()
    }

    private func resize() {
      let newCapacity = storage.count * 2
      var newStorage = [FrameJob?](repeating: nil, count: newCapacity)
      for i in 0..<count {
        newStorage[i] = storage[(head + i) & (storage.count - 1)]
      }
      storage = newStorage
      head = 0
      tail = count
    }
  }

  private final class Metrics: @unchecked Sendable {
    private let lock = NSLock()

    private var sampleMatchSeconds: Double = 0
    private var segmentSeconds: Double = 0
    private var renderSeconds: Double = 0
    private var appendSeconds: Double = 0

    private var queuedFrames = 0
    private var renderedFrames = 0
    private var appendedFrames = 0
    private var droppedPoolFrames = 0

    func addSampleMatch(_ seconds: Double) {
      lock.lock()
      sampleMatchSeconds += seconds
      lock.unlock()
    }

    func addSegment(_ seconds: Double) {
      lock.lock()
      segmentSeconds += seconds
      lock.unlock()
    }

    func addRender(_ seconds: Double) {
      lock.lock()
      renderSeconds += seconds
      lock.unlock()
    }

    func addAppend(_ seconds: Double) {
      lock.lock()
      appendSeconds += seconds
      lock.unlock()
    }

    func incQueued() {
      lock.lock()
      queuedFrames += 1
      lock.unlock()
    }

    func incRendered() {
      lock.lock()
      renderedFrames += 1
      lock.unlock()
    }

    func incAppended() {
      lock.lock()
      appendedFrames += 1
      lock.unlock()
    }

    func incDroppedPool() {
      lock.lock()
      droppedPoolFrames += 1
      lock.unlock()
    }

    func snapshot() -> Snapshot {
      lock.lock()
      defer { lock.unlock() }
      return Snapshot(
        sampleMatchSeconds: sampleMatchSeconds,
        segmentSeconds: segmentSeconds,
        renderSeconds: renderSeconds,
        appendSeconds: appendSeconds,
        queuedFrames: queuedFrames,
        renderedFrames: renderedFrames,
        appendedFrames: appendedFrames,
        droppedPoolFrames: droppedPoolFrames
      )
    }

    struct Snapshot {
      let sampleMatchSeconds: Double
      let segmentSeconds: Double
      let renderSeconds: Double
      let appendSeconds: Double
      let queuedFrames: Int
      let renderedFrames: Int
      let appendedFrames: Int
      let droppedPoolFrames: Int
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
    private let doneSignal = DoneCondition()

    private let totalFrames: Int
    private let progressHandler: (@MainActor @Sendable (Double, Double?) -> Void)?
    private let startTime: CFAbsoluteTime
    private let backpressure: CountingCondition
    private let metrics: Metrics

    init(
      adaptor: AVAssetWriterInputPixelBufferAdaptor,
      input: AVAssetWriterInput,
      totalFrames: Int,
      progressHandler: (@MainActor @Sendable (Double, Double?) -> Void)?,
      backpressure: CountingCondition,
      metrics: Metrics
    ) {
      self.adaptor = adaptor
      self.input = input
      self.totalFrames = totalFrames
      self.progressHandler = progressHandler
      self.startTime = CFAbsoluteTimeGetCurrent()
      self.backpressure = backpressure
      self.metrics = metrics
    }

    func start() {
      input.requestMediaDataWhenReady(
        on: DispatchQueue(label: "eu.jankuri.reframed.video-writer", qos: .userInitiated)
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

      backpressure.signal(times: pendingCount)

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

        let appendStart = CFAbsoluteTimeGetCurrent()
        let appended = adaptor.append(buf, withPresentationTime: time)
        let appendEnd = CFAbsoluteTimeGetCurrent()

        metrics.addAppend(appendEnd - appendStart)
        if appended {
          metrics.incAppended()
        }

        backpressure.signal()

        if writtenCount % 30 == 0 || writtenCount == totalFrames {
          let progress = (Double(writtenCount) / Double(max(totalFrames, 1))) * 0.99
          let elapsed = CFAbsoluteTimeGetCurrent() - startTime
          let remaining = Double(totalFrames - writtenCount)
          let secsPerFrame = elapsed / Double(max(writtenCount, 1))
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

    let coreCount = max(1, ProcessInfo.processInfo.activeProcessorCount)
    let workerCount = coreCount
    let maxInFlight = min(max(workerCount * 2, 8), 20)

    var poolRef: CVPixelBufferPool?
    let poolAttrs: NSDictionary = [kCVPixelBufferPoolMinimumBufferCountKey: maxInFlight + 4]
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
    let metrics = Metrics()
    let exportStart = CFAbsoluteTimeGetCurrent()

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
    let sem = CountingCondition(value: maxInFlight)

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
                if audioState.finished {
                  audioState.lock.unlock()
                  break
                }
                audioState.lock.unlock()

                if cancelToken.isCancelled {
                  safeAudioInput.markAsFinished()
                  audioState.lock.lock()
                  if !audioState.finished {
                    audioState.finished = true
                    audioGroup.leave()
                  }
                  audioState.lock.unlock()
                  break
                }

                if let sample = safeAudioOutput.copyNextSampleBuffer() {
                  _ = safeAudioInput.append(sample)
                } else {
                  safeAudioInput.markAsFinished()
                  audioState.lock.lock()
                  if !audioState.finished {
                    audioState.finished = true
                    audioGroup.leave()
                  }
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
            backpressure: sem,
            metrics: metrics
          )
          frameWriter.start()

          let jobs = FrameJobQueue(initialCapacity: max(256, maxInFlight * 4))
          let renderGroup = DispatchGroup()
          let renderQueue = DispatchQueue(
            label: "eu.jankuri.reframed.render-workers",
            qos: .userInitiated,
            attributes: .concurrent
          )

          let hasCameraBg = instruction.cameraBackgroundStyle != .none
          let segPool = hasCameraBg ? SegmentationProcessorPool(maxCount: workerCount, quality: .balanced) : nil

          for _ in 0..<workerCount {
            renderGroup.enter()
            renderQueue.async {
              defer { renderGroup.leave() }

              while !cancelToken.isCancelled {
                guard let job = jobs.pop() else { break }

                autoreleasepool {
                  var processedWebcam: CGImage?

                  if let wb = job.webcamBuffer, let segPool, !cancelToken.isCancelled {
                    let segStart = CFAbsoluteTimeGetCurrent()
                    processedWebcam = segPool.process(
                      webcamBuffer: wb,
                      style: job.style,
                      backgroundCGImage: job.backgroundImage
                    )
                    let segEnd = CFAbsoluteTimeGetCurrent()
                    metrics.addSegment(segEnd - segStart)
                  }

                  if cancelToken.isCancelled {
                    frameWriter.submit(index: job.index, buffer: job.outputBuffer, time: job.time)
                    return
                  }

                  let renderStart = CFAbsoluteTimeGetCurrent()
                  FrameRenderer.renderFrame(
                    screenBuffer: job.screenBuffer,
                    webcamBuffer: job.webcamBuffer,
                    outputBuffer: job.outputBuffer,
                    compositionTime: job.sourceTime,
                    instruction: instruction,
                    processedWebcamImage: processedWebcam
                  )
                  let renderEnd = CFAbsoluteTimeGetCurrent()

                  metrics.addRender(renderEnd - renderStart)
                  metrics.incRendered()

                  frameWriter.submit(index: job.index, buffer: job.outputBuffer, time: job.time)
                }
              }
            }
          }

          var latestScreenSample: CMSampleBuffer?
          var nextScreenSample: CMSampleBuffer? = pipelineScreenOutput.copyNextSampleBuffer()
          var latestWebcamSample: CMSampleBuffer?
          var nextWebcamSample: CMSampleBuffer? = pipelineWebcamOutput?.copyNextSampleBuffer()

          for frameIndex in 0..<totalFrames {
            if cancelToken.isCancelled { break }

            let matchStart = CFAbsoluteTimeGetCurrent()

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

            let matchEnd = CFAbsoluteTimeGetCurrent()
            metrics.addSampleMatch(matchEnd - matchStart)

            guard let screenBuffer = latestScreenSample.flatMap({ CMSampleBufferGetImageBuffer($0) }) else {
              continue
            }

            let webcamBuffer = latestWebcamSample.flatMap { CMSampleBufferGetImageBuffer($0) }

            sem.wait()
            if cancelToken.isCancelled {
              sem.signal()
              break
            }

            var outBuf: CVPixelBuffer?
            let poolStatus = CVPixelBufferPoolCreatePixelBuffer(nil, pipelineOutputPool, &outBuf)
            guard poolStatus == kCVReturnSuccess, let outputBuffer = outBuf else {
              metrics.incDroppedPool()
              sem.signal()
              continue
            }

            let job = FrameJob(
              index: frameIndex,
              time: outputTime,
              sourceTime: sourceTime,
              screenBuffer: screenBuffer,
              webcamBuffer: webcamBuffer,
              outputBuffer: outputBuffer,
              style: instruction.cameraBackgroundStyle,
              backgroundImage: instruction.cameraBackgroundImage
            )

            metrics.incQueued()
            jobs.push(job)
          }

          latestScreenSample = nil
          nextScreenSample = nil
          latestWebcamSample = nil
          nextWebcamSample = nil

          jobs.close()
          renderGroup.wait()

          if cancelToken.isCancelled {
            frameWriter.cancel()
            pipelineAudioReader?.cancelReading()
            pipelineReader.cancelReading()
            pipelineWriter.cancelWriting()
            CVPixelBufferPoolFlush(pipelineOutputPool, .excessBuffers)
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
            CVPixelBufferPoolFlush(pipelineOutputPool, .excessBuffers)
            try? FileManager.default.removeItem(at: outputURL)
            safeCont.resume(throwing: CancellationError())
            return
          }

          pipelineWriter.finishWriting {
            CVPixelBufferPoolFlush(pipelineOutputPool, .excessBuffers)

            let exportEnd = CFAbsoluteTimeGetCurrent()
            let totalSeconds = exportEnd - exportStart
            let m = metrics.snapshot()

            let queued = max(m.queuedFrames, 1)
            let rendered = max(m.renderedFrames, 1)
            let appended = max(m.appendedFrames, 1)

            logger.info("Parallel render export completed (\(workerCount) workers, \(coreCount) cores)")
            logger.info("Export total: \(String(format: "%.3f", totalSeconds))s")
            logger.info(
              "Frames queued: \(m.queuedFrames), rendered: \(m.renderedFrames), appended: \(m.appendedFrames), poolDrops: \(m.droppedPoolFrames)"
            )
            logger.info(
              "Sample match total: \(String(format: "%.3f", m.sampleMatchSeconds))s avg/frame: \(String(format: "%.3f", (m.sampleMatchSeconds / Double(queued)) * 1000))ms"
            )
            logger.info(
              "Segmentation total: \(String(format: "%.3f", m.segmentSeconds))s avg/rendered: \(String(format: "%.3f", (m.segmentSeconds / Double(rendered)) * 1000))ms"
            )
            logger.info(
              "Render total: \(String(format: "%.3f", m.renderSeconds))s avg/rendered: \(String(format: "%.3f", (m.renderSeconds / Double(rendered)) * 1000))ms"
            )
            logger.info(
              "Append total: \(String(format: "%.3f", m.appendSeconds))s avg/appended: \(String(format: "%.3f", (m.appendSeconds / Double(appended)) * 1000))ms"
            )
            logger.info(
              "Throughput queued: \(String(format: "%.2f", Double(m.queuedFrames) / max(totalSeconds, 0.0001))) fps, appended: \(String(format: "%.2f", Double(m.appendedFrames) / max(totalSeconds, 0.0001))) fps"
            )

            if pipelineWriter.status == .failed {
              safeCont.resume(
                throwing: pipelineWriter.error ?? CaptureError.recordingFailed("Export writing failed")
              )
            } else {
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
      sem.signal(times: maxInFlight + workerCount + 8)
    }
  }
}

private extension Int {
  var nextPowerOfTwo: Int {
    if self <= 1 { return 1 }
    var x = self - 1
    x |= x >> 1
    x |= x >> 2
    x |= x >> 4
    x |= x >> 8
    x |= x >> 16
    #if arch(x86_64) || arch(arm64)
    x |= x >> 32
    #endif
    return x + 1
  }
}
