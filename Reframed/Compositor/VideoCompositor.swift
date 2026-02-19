import AVFoundation
import CoreMedia
import Foundation
import Logging
import VideoToolbox
import gifski

enum VideoCompositor {
  private static let logger = Logger(label: "eu.jankuri.reframed.video-compositor")

  private struct AudioSource {
    let url: URL
    let regions: [CMTimeRange]
    let volume: Float
  }

  static func export(
    result: RecordingResult,
    cameraLayout: CameraLayout,
    cameraAspect: CameraAspect = .original,
    trimRange: CMTimeRange,
    systemAudioRegions: [CMTimeRange]? = nil,
    micAudioRegions: [CMTimeRange]? = nil,
    cameraFullscreenRegions: [CMTimeRange]? = nil,
    backgroundStyle: BackgroundStyle = .none,
    backgroundImageURL: URL? = nil,
    backgroundImageFillMode: BackgroundImageFillMode = .fill,
    canvasAspect: CanvasAspect = .original,
    padding: CGFloat = 0,
    videoCornerRadius: CGFloat = 0,
    cameraCornerRadius: CGFloat = 12,
    cameraBorderWidth: CGFloat = 0,
    cameraBorderColor: CodableColor = CodableColor(r: 1, g: 1, b: 1, a: 0.3),
    videoShadow: CGFloat = 0,
    cameraShadow: CGFloat = 0,
    cameraMirrored: Bool = false,
    cameraFullscreenFillMode: CameraFullscreenFillMode = .fit,
    cameraFullscreenAspect: CameraFullscreenAspect = .original,
    exportSettings: ExportSettings = ExportSettings(),
    cursorSnapshot: CursorMetadataSnapshot? = nil,
    cursorStyle: CursorStyle = .defaultArrow,
    cursorSize: CGFloat = 24,
    showClickHighlights: Bool = true,
    clickHighlightColor: CGColor = CGColor(srgbRed: 0.2, green: 0.5, blue: 1.0, alpha: 1.0),
    clickHighlightSize: CGFloat = 36,
    zoomFollowCursor: Bool = true,
    zoomTimeline: ZoomTimeline? = nil,
    systemAudioVolume: Float = 1.0,
    micAudioVolume: Float = 1.0,
    micNoiseReductionEnabled: Bool = false,
    micNoiseReductionIntensity: Float = 0.5,
    processedMicAudioURL: URL? = nil,
    progressHandler: (@MainActor @Sendable (Double, Double?) -> Void)? = nil
  ) async throws -> URL {
    let composition = AVMutableComposition()
    let screenAsset = AVURLAsset(url: result.screenVideoURL)

    guard let screenVideoTrack = try await screenAsset.loadTracks(withMediaType: .video).first else {
      throw CaptureError.recordingFailed("No video track in screen recording")
    }

    let screenNaturalSize = try await screenVideoTrack.load(.naturalSize)
    let screenTimeRange = try await screenVideoTrack.load(.timeRange)

    let effectiveTrim: CMTimeRange
    if trimRange.duration.isValid && CMTimeCompare(trimRange.duration, .zero) > 0 {
      effectiveTrim = trimRange
    } else {
      effectiveTrim = screenTimeRange
    }

    let compScreenTrack = composition.addMutableTrack(
      withMediaType: .video,
      preferredTrackID: 1
    )
    try compScreenTrack?.insertTimeRange(effectiveTrim, of: screenVideoTrack, at: .zero)

    var processedMicURL: URL?
    var shouldCleanupProcessedMic = false
    if let micURL = result.microphoneAudioURL, micNoiseReductionEnabled, micAudioVolume > 0 {
      if let cachedURL = processedMicAudioURL, FileManager.default.fileExists(atPath: cachedURL.path) {
        processedMicURL = cachedURL
      } else {
        let tempURL = FileManager.default.temporaryDirectory
          .appendingPathComponent("reframed-nr-\(UUID().uuidString).m4a")
        try await RNNoiseProcessor.processFile(
          inputURL: micURL,
          outputURL: tempURL,
          intensity: micNoiseReductionIntensity
        )
        processedMicURL = tempURL
        shouldCleanupProcessedMic = true
      }
    }
    defer {
      if shouldCleanupProcessedMic, let url = processedMicURL {
        try? FileManager.default.removeItem(at: url)
      }
    }

    var audioSources: [AudioSource] = []
    if let sysURL = result.systemAudioURL, systemAudioVolume > 0 {
      audioSources.append(
        AudioSource(url: sysURL, regions: systemAudioRegions ?? [effectiveTrim], volume: systemAudioVolume)
      )
    }
    if let micURL = result.microphoneAudioURL, micAudioVolume > 0 {
      let effectiveMicURL = processedMicURL ?? micURL
      audioSources.append(
        AudioSource(
          url: effectiveMicURL,
          regions: micAudioRegions ?? [effectiveTrim],
          volume: micAudioVolume
        )
      )
    }

    let hasNonDefaultBackground: Bool = {
      switch backgroundStyle {
      case .none: return false
      case .solidColor(let c): return !(c.r == 0 && c.g == 0 && c.b == 0)
      case .gradient, .image: return true
      }
    }()
    let hasVisualEffects =
      hasNonDefaultBackground || canvasAspect != .original || padding > 0 || videoCornerRadius > 0
      || videoShadow > 0
    let hasWebcam = result.webcamVideoURL != nil
    let hasCursor = cursorSnapshot != nil
    let hasZoom = zoomTimeline != nil
    let sourceCodecMatchesExport: Bool = {
      switch result.captureQuality {
      case .veryHigh: return exportSettings.codec == .proRes4444
      case .high: return exportSettings.codec == .proRes422
      case .standard: return exportSettings.codec == .h264
      }
    }()
    let needsReencode =
      !sourceCodecMatchesExport || exportSettings.resolution != .original
      || exportSettings.fps != .original
    let needsCompositor =
      hasVisualEffects || hasWebcam || needsReencode || hasCursor || hasZoom
      || exportSettings.format.isGIF

    let canvasSize: CGSize
    if let baseSize = canvasAspect.size(for: screenNaturalSize) {
      canvasSize = baseSize
    } else if padding > 0 {
      let scale = 1.0 + 2.0 * padding
      canvasSize = CGSize(width: screenNaturalSize.width * scale, height: screenNaturalSize.height * scale)
    } else {
      canvasSize = screenNaturalSize
    }

    let renderSize: CGSize
    if let targetWidth = exportSettings.resolution.pixelWidth {
      let aspect = canvasSize.height / max(canvasSize.width, 1)
      renderSize = CGSize(width: targetWidth, height: round(targetWidth * aspect))
    } else {
      renderSize = canvasSize
    }

    let exportFPS = exportSettings.fps.value(fallback: result.fps)

    if needsCompositor {
      var webcamTrackID: CMPersistentTrackID?
      var cameraRect: CGRect?

      if let webcamURL = result.webcamVideoURL, let webcamSize = result.webcamSize {
        let webcamAsset = AVURLAsset(url: webcamURL)
        if let webcamVideoTrack = try await webcamAsset.loadTracks(withMediaType: .video).first {
          let wTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: 2
          )
          try wTrack?.insertTimeRange(effectiveTrim, of: webcamVideoTrack, at: .zero)
          webcamTrackID = 2
          cameraRect = cameraLayout.pixelRect(screenSize: canvasSize, webcamSize: webcamSize, cameraAspect: cameraAspect)
        }
      }

      let bgColors = backgroundColorTuples(for: backgroundStyle)
      let bgStartPoint: CGPoint
      let bgEndPoint: CGPoint
      if case .gradient(let id) = backgroundStyle, let preset = GradientPresets.preset(for: id) {
        bgStartPoint = preset.cgStartPoint
        bgEndPoint = preset.cgEndPoint
      } else {
        bgStartPoint = .zero
        bgEndPoint = CGPoint(x: 0, y: 1)
      }

      var bgImage: CGImage?
      if case .image = backgroundStyle, let imageURL = backgroundImageURL,
        let dataProvider = CGDataProvider(url: imageURL as CFURL),
        let source = CGImageSourceCreateWithDataProvider(dataProvider, nil),
        CGImageSourceGetCount(source) > 0
      {
        bgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
      }

      let scaleX = renderSize.width / canvasSize.width
      let scaleY = renderSize.height / canvasSize.height
      let paddingHPx = padding * screenNaturalSize.width * scaleX
      let paddingVPx = padding * screenNaturalSize.height * scaleY

      let scaledCornerRadius: CGFloat = {
        let paddedW = renderSize.width - 2 * paddingHPx
        let paddedH = renderSize.height - 2 * paddingVPx
        let paddedArea = CGRect(x: 0, y: 0, width: paddedW, height: paddedH)
        let videoFitRect = AVMakeRect(aspectRatio: screenNaturalSize, insideRect: paddedArea)
        return min(videoFitRect.width, videoFitRect.height) * (videoCornerRadius / 100.0)
      }()

      let instruction = CompositionInstruction(
        timeRange: CMTimeRange(start: .zero, duration: effectiveTrim.duration),
        screenTrackID: 1,
        webcamTrackID: webcamTrackID,
        cameraRect: cameraRect.map { rect in
          let scaleX = renderSize.width / canvasSize.width
          let scaleY = renderSize.height / canvasSize.height
          return CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
          )
        },
        cameraCornerRadius: {
          guard let rect = cameraRect else { return 0 }
          let sX = renderSize.width / canvasSize.width
          let sY = renderSize.height / canvasSize.height
          let scaledW = rect.width * sX
          let scaledH = rect.height * sY
          return min(scaledW, scaledH) * (cameraCornerRadius / 100.0)
        }(),
        cameraBorderWidth: cameraBorderWidth * (renderSize.width / canvasSize.width),
        cameraBorderColor: cameraBorderColor.cgColor,
        videoShadow: videoShadow,
        cameraShadow: cameraShadow,
        cameraMirrored: cameraMirrored,
        outputSize: renderSize,
        backgroundColors: bgColors,
        backgroundStartPoint: bgStartPoint,
        backgroundEndPoint: bgEndPoint,
        backgroundImage: bgImage,
        backgroundImageFillMode: backgroundImageFillMode,
        paddingH: paddingHPx,
        paddingV: paddingVPx,
        videoCornerRadius: scaledCornerRadius,
        canvasSize: renderSize,
        cursorSnapshot: cursorSnapshot,
        cursorStyle: cursorStyle,
        cursorSize: cursorSize,
        showCursor: cursorSnapshot != nil,
        showClickHighlights: showClickHighlights,
        clickHighlightColor: clickHighlightColor,
        clickHighlightSize: clickHighlightSize,
        zoomFollowCursor: zoomFollowCursor,
        zoomTimeline: zoomTimeline,
        trimStartSeconds: CMTimeGetSeconds(effectiveTrim.start),
        cameraFullscreenRegions: (cameraFullscreenRegions ?? []).compactMap { region in
          let overlapStart = CMTimeMaximum(region.start, effectiveTrim.start)
          let overlapEnd = CMTimeMinimum(region.end, effectiveTrim.end)
          guard CMTimeCompare(overlapEnd, overlapStart) > 0 else { return nil }
          return CMTimeRange(
            start: CMTimeSubtract(overlapStart, effectiveTrim.start),
            end: CMTimeSubtract(overlapEnd, effectiveTrim.start)
          )
        },
        cameraFullscreenFillMode: cameraFullscreenFillMode,
        cameraFullscreenAspect: cameraFullscreenAspect
      )

      if exportSettings.format.isGIF {
        let outputURL = FileManager.default.tempGIFURL()
        try await gifExport(
          composition: composition,
          instruction: instruction,
          renderSize: renderSize,
          fps: exportFPS,
          trimDuration: effectiveTrim.duration,
          outputURL: outputURL,
          gifQuality: exportSettings.gifQuality.value,
          progressHandler: progressHandler
        )

        let destination = await MainActor.run {
          FileManager.default.defaultSaveURL(for: outputURL, extension: "gif")
        }
        try FileManager.default.moveToFinal(from: outputURL, to: destination)

        logger.info("GIF export saved: \(destination.path)")
        return destination
      }

      let videoComposition = AVMutableVideoComposition()
      videoComposition.customVideoCompositorClass = CameraVideoCompositor.self
      videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(exportFPS))
      videoComposition.renderSize = renderSize
      videoComposition.instructions = [instruction]

      try await addAudioTracks(to: composition, sources: audioSources, videoTrimRange: effectiveTrim)
      let audioMix = buildAudioMix(for: composition, sources: audioSources)

      let outputURL = FileManager.default.tempRecordingURL()

      if exportSettings.mode == .parallel {
        try await parallelRenderExport(
          composition: composition,
          instruction: instruction,
          renderSize: renderSize,
          fps: exportFPS,
          trimDuration: effectiveTrim.duration,
          outputURL: outputURL,
          fileType: exportSettings.format.fileType,
          codec: exportSettings.codec,
          audioMix: audioMix,
          audioBitrate: exportSettings.audioBitrate.value,
          progressHandler: progressHandler
        )
      } else {
        try await runManualExport(
          asset: composition,
          videoComposition: videoComposition,
          timeRange: CMTimeRange(start: .zero, duration: effectiveTrim.duration),
          renderSize: renderSize,
          codec: exportSettings.codec.videoCodecType,
          exportFPS: Double(exportFPS),
          to: outputURL,
          fileType: exportSettings.format.fileType,
          audioMix: audioMix,
          audioBitrate: exportSettings.audioBitrate.value,
          progressHandler: progressHandler
        )
      }

      let destination = await MainActor.run {
        FileManager.default.defaultSaveURL(for: outputURL, extension: exportSettings.format.fileExtension)
      }
      try FileManager.default.moveToFinal(from: outputURL, to: destination)

      logger.info("Composited export saved: \(destination.path)")
      return destination
    }

    try await addAudioTracks(to: composition, sources: audioSources, videoTrimRange: effectiveTrim)

    let outputURL = FileManager.default.tempRecordingURL()
    guard
      let exportSession = AVAssetExportSession(
        asset: composition,
        presetName: AVAssetExportPresetPassthrough
      )
    else {
      throw CaptureError.recordingFailed("Failed to create export session")
    }

    exportSession.timeRange = CMTimeRange(start: .zero, duration: effectiveTrim.duration)
    if let audioMix = buildAudioMix(for: composition, sources: audioSources) {
      exportSession.audioMix = audioMix
    }
    try await runExport(exportSession, to: outputURL, fileType: exportSettings.format.fileType, progressHandler: progressHandler)

    let destination = await MainActor.run {
      FileManager.default.defaultSaveURL(for: outputURL, extension: exportSettings.format.fileExtension)
    }
    try FileManager.default.moveToFinal(from: outputURL, to: destination)

    logger.info("Passthrough export saved: \(destination.path)")
    return destination
  }

  private final class ExportProgressPoller: @unchecked Sendable {
    private let session: AVAssetExportSession
    init(_ session: AVAssetExportSession) { self.session = session }
    var progress: Double { Double(session.progress) }
  }

  private static func runExport(
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

  private static func runManualExport(
    asset: AVAsset,
    videoComposition: AVVideoComposition?,
    timeRange: CMTimeRange,
    renderSize: CGSize,
    codec: AVVideoCodecType,
    exportFPS: Double,
    to url: URL,
    fileType: AVFileType,
    audioMix: AVAudioMix? = nil,
    audioBitrate: Int = 320_000,
    progressHandler: (@MainActor @Sendable (Double, Double?) -> Void)?
  ) async throws {
    nonisolated(unsafe) let reader = try AVAssetReader(asset: asset)
    reader.timeRange = timeRange

    let videoTracks = try await asset.loadTracks(withMediaType: .video)
    nonisolated(unsafe) let videoOutput = AVAssetReaderVideoCompositionOutput(
      videoTracks: videoTracks,
      videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    )
    videoOutput.videoComposition = videoComposition
    reader.add(videoOutput)

    let audioTracks = try await asset.loadTracks(withMediaType: .audio)
    nonisolated(unsafe) var audioOutput: AVAssetReaderAudioMixOutput?
    if !audioTracks.isEmpty {
      let aOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)
      if let audioMix {
        aOutput.audioMix = audioMix
      }
      reader.add(aOutput)
      audioOutput = aOutput
    }

    nonisolated(unsafe) let writer = try AVAssetWriter(url: url, fileType: fileType)

    let pixels = Double(renderSize.width * renderSize.height)
    let videoSettings: [String: Any]
    if codec == .proRes4444 || codec == .proRes422 {
      videoSettings = [
        AVVideoCodecKey: codec,
        AVVideoWidthKey: Int(renderSize.width),
        AVVideoHeightKey: Int(renderSize.height),
      ]
    } else {
      let compressionProperties: [String: Any]
      if codec == .hevc {
        compressionProperties = [AVVideoAverageBitRateKey: pixels * exportFPS * 0.04]
      } else {
        compressionProperties = [AVVideoAverageBitRateKey: pixels * exportFPS * 0.06]
      }
      videoSettings = [
        AVVideoCodecKey: codec,
        AVVideoWidthKey: Int(renderSize.width),
        AVVideoHeightKey: Int(renderSize.height),
        AVVideoCompressionPropertiesKey: compressionProperties,
      ]
    }
    nonisolated(unsafe) let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    videoInput.expectsMediaDataInRealTime = false
    writer.add(videoInput)

    nonisolated(unsafe) var audioInput: AVAssetWriterInput?
    if audioOutput != nil {
      let audioSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVNumberOfChannelsKey: 2,
        AVSampleRateKey: 44100,
        AVEncoderBitRateKey: audioBitrate,
      ]
      let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
      aInput.expectsMediaDataInRealTime = false
      writer.add(aInput)
      audioInput = aInput
    }

    guard reader.startReading() else {
      throw CaptureError.recordingFailed(
        "AVAssetReader failed to start: \(reader.error?.localizedDescription ?? "unknown")"
      )
    }
    writer.startWriting()
    writer.startSession(atSourceTime: timeRange.start)

    let totalFrames = max(floor(CMTimeGetSeconds(timeRange.duration) * exportFPS) + 1, 1)
    let exportStartTime = CFAbsoluteTimeGetCurrent()
    nonisolated(unsafe) let cancelled = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
    cancelled.initialize(to: false)
    defer { cancelled.deallocate() }

    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        nonisolated(unsafe) var sampleCount = 0
        nonisolated(unsafe) var continued = false

        let group = DispatchGroup()
        let videoQueue = DispatchQueue(label: "eu.jankuri.reframed.export.video", qos: .userInitiated)
        let audioQueue = DispatchQueue(label: "eu.jankuri.reframed.export.audio", qos: .userInitiated)

        func finishIfNeeded() {
          guard !continued else { return }
          continued = true

          if cancelled.pointee {
            reader.cancelReading()
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: url)
            continuation.resume(throwing: CancellationError())
            return
          }

          if reader.status == .failed {
            writer.cancelWriting()
            continuation.resume(
              throwing: CaptureError.recordingFailed(
                "AVAssetReader failed: \(reader.error?.localizedDescription ?? "unknown")"
              )
            )
            return
          }

          writer.finishWriting {
            if writer.status == .failed {
              continuation.resume(
                throwing: CaptureError.recordingFailed(
                  "AVAssetWriter failed: \(writer.error?.localizedDescription ?? "unknown")"
                )
              )
            } else {
              continuation.resume()
            }
          }
        }

        group.enter()
        videoInput.requestMediaDataWhenReady(on: videoQueue) {
          while videoInput.isReadyForMoreMediaData {
            if cancelled.pointee {
              videoInput.markAsFinished()
              group.leave()
              return
            }
            if let buffer = videoOutput.copyNextSampleBuffer() {
              videoInput.append(buffer)
              sampleCount += 1
              if sampleCount % 10 == 0, let handler = progressHandler {
                let progress = min(Double(sampleCount) / totalFrames, 1.0)
                let elapsed = CFAbsoluteTimeGetCurrent() - exportStartTime
                let remaining = Double(Int(totalFrames) - sampleCount)
                let secsPerFrame = elapsed / Double(sampleCount)
                let eta = remaining * secsPerFrame
                Task { @MainActor in handler(progress, eta) }
              }
            } else {
              videoInput.markAsFinished()
              group.leave()
              return
            }
          }
        }

        if let aOut = audioOutput, let aIn = audioInput {
          nonisolated(unsafe) let safeAudioOutput = aOut
          nonisolated(unsafe) let safeAudioInput = aIn
          group.enter()
          safeAudioInput.requestMediaDataWhenReady(on: audioQueue) {
            while safeAudioInput.isReadyForMoreMediaData {
              if cancelled.pointee {
                safeAudioInput.markAsFinished()
                group.leave()
                return
              }
              if let buffer = safeAudioOutput.copyNextSampleBuffer() {
                safeAudioInput.append(buffer)
              } else {
                safeAudioInput.markAsFinished()
                group.leave()
                return
              }
            }
          }
        }

        group.notify(queue: .main) {
          finishIfNeeded()
        }
      }
    } onCancel: {
      cancelled.pointee = true
    }

    if let handler = progressHandler {
      await handler(1.0, 0)
    }
  }

  private final class OrderedFrameWriter: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [Int: (CVPixelBuffer, CMTime)] = [:]
    private var nextIndex = 0
    private var draining = false
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let input: AVAssetWriterInput
    private var finished = false
    private var hasSignaled = false
    private let doneSignal = DispatchSemaphore(value: 0)

    private let totalFrames: Int
    private let progressHandler: (@MainActor @Sendable (Double, Double?) -> Void)?
    private let startTime: CFAbsoluteTime
    private let backpressure: DispatchSemaphore?

    init(
      adaptor: AVAssetWriterInputPixelBufferAdaptor,
      input: AVAssetWriterInput,
      totalFrames: Int,
      progressHandler: (@MainActor @Sendable (Double, Double?) -> Void)?,
      backpressure: DispatchSemaphore? = nil
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

    func waitUntilDone() {
      doneSignal.wait()
    }

    private func drain() {
      lock.lock()
      if draining {
        lock.unlock()
        return
      }
      draining = true

      while true {
        guard input.isReadyForMoreMediaData, let (buf, time) = pending[nextIndex] else {
          break
        }
        pending.removeValue(forKey: nextIndex)
        nextIndex += 1
        let writtenCount = nextIndex
        lock.unlock()

        adaptor.append(buf, withPresentationTime: time)
        backpressure?.signal()

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

      let shouldSignalDone = finished && pending.isEmpty && !hasSignaled
      if shouldSignalDone { hasSignaled = true }
      draining = false
      lock.unlock()

      if shouldSignalDone {
        doneSignal.signal()
      }
    }
  }

  private static func parallelRenderExport(
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
    let videoOutputSettings: [String: Any]
    if codec.isProRes {
      videoOutputSettings = [
        AVVideoCodecKey: videoCodec,
        AVVideoWidthKey: Int(renderSize.width),
        AVVideoHeightKey: Int(renderSize.height),
      ]
    } else {
      let pixels = Double(renderSize.width * renderSize.height)
      let exportFPS = Double(fps)
      let bitRate: Double
      if codec == .h265 {
        bitRate = pixels * exportFPS * 0.04
      } else {
        bitRate = pixels * exportFPS * 0.06
      }
      var compressionProperties: [String: Any] = [
        AVVideoAverageBitRateKey: bitRate,
        AVVideoAllowFrameReorderingKey: false,
        AVVideoExpectedSourceFrameRateKey: fps,
        kVTCompressionPropertyKey_RealTime as String: true,
      ]
      if codec == .h265 {
        compressionProperties[kVTCompressionPropertyKey_PrioritizeEncodingSpeedOverQuality as String] = true
      }
      videoOutputSettings = [
        AVVideoCodecKey: videoCodec,
        AVVideoWidthKey: Int(renderSize.width),
        AVVideoHeightKey: Int(renderSize.height),
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
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
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
    let batchSize = max(coreCount * 3, 24)

    let bytesPerFrame = Int(renderSize.width) * Int(renderSize.height) * 4
    let maxMemoryBytes = 1_500_000_000
    let maxInFlight = max(batchSize * 3, min(maxMemoryBytes / max(bytesPerFrame, 1), 120))

    var poolRef: CVPixelBufferPool?
    let poolAttrs: NSDictionary = [kCVPixelBufferPoolMinimumBufferCountKey: maxInFlight + 4]
    let pbAttrs: NSDictionary = [
      kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
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

    nonisolated(unsafe) let cancelled = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
    cancelled.initialize(to: false)
    defer { cancelled.deallocate() }

    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
        DispatchQueue.global(qos: .userInitiated).async {
          let audioGroup = DispatchGroup()
          if let aOut = pipelineAudioOutput, let aIn = pipelineAudioWriterInput,
            pipelineAudioReader?.status == .reading
          {
            nonisolated(unsafe) let safeAudioOutput = aOut
            nonisolated(unsafe) let safeAudioInput = aIn
            audioGroup.enter()
            let audioQueue = DispatchQueue(label: "eu.jankuri.reframed.audio", qos: .userInitiated)
            safeAudioInput.requestMediaDataWhenReady(on: audioQueue) {
              while safeAudioInput.isReadyForMoreMediaData {
                if cancelled.pointee {
                  safeAudioInput.markAsFinished()
                  audioGroup.leave()
                  return
                }
                if let sample = safeAudioOutput.copyNextSampleBuffer() {
                  safeAudioInput.append(sample)
                } else {
                  safeAudioInput.markAsFinished()
                  audioGroup.leave()
                  break
                }
              }
            }
          } else {
            pipelineAudioWriterInput?.markAsFinished()
          }

          let sem = DispatchSemaphore(value: maxInFlight)
          let frameWriter = OrderedFrameWriter(
            adaptor: pipelineAdaptor,
            input: pipelineVideoInput,
            totalFrames: totalFrames,
            progressHandler: progressHandler,
            backpressure: sem
          )
          frameWriter.start()

          var latestScreenSample: CMSampleBuffer?
          var nextScreenSample: CMSampleBuffer? = pipelineScreenOutput.copyNextSampleBuffer()
          var latestWebcamSample: CMSampleBuffer?
          var nextWebcamSample: CMSampleBuffer? = pipelineWebcamOutput?.copyNextSampleBuffer()

          for batchStart in stride(from: 0, to: totalFrames, by: batchSize) {
            if cancelled.pointee { break }

            let batchEnd = min(batchStart + batchSize, totalFrames)
            let batchCount = batchEnd - batchStart

            var batchScreenSamples: [CMSampleBuffer?] = Array(repeating: nil, count: batchCount)
            var batchWebcamSamples: [CMSampleBuffer?] = Array(repeating: nil, count: batchCount)
            var batchScreenBuffers: [CVPixelBuffer?] = Array(repeating: nil, count: batchCount)
            var batchWebcamBuffers: [CVPixelBuffer?] = Array(repeating: nil, count: batchCount)
            var batchTimes: [CMTime] = Array(repeating: .zero, count: batchCount)

            for i in 0..<batchCount {
              let frameIndex = batchStart + i
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

              batchScreenSamples[i] = latestScreenSample
              batchWebcamSamples[i] = latestWebcamSample
              batchScreenBuffers[i] = latestScreenSample.flatMap { CMSampleBufferGetImageBuffer($0) }
              batchWebcamBuffers[i] = latestWebcamSample.flatMap { CMSampleBufferGetImageBuffer($0) }
              batchTimes[i] = outputTime
            }

            var outputBuffers: [CVPixelBuffer?] = Array(repeating: nil, count: batchCount)
            for i in 0..<batchCount {
              if cancelled.pointee { break }
              guard batchScreenBuffers[i] != nil else { continue }
              sem.wait()
              if cancelled.pointee { sem.signal(); break }
              var outBuf: CVPixelBuffer?
              CVPixelBufferPoolCreatePixelBuffer(nil, pipelineOutputPool, &outBuf)
              if outBuf == nil { sem.signal() }
              outputBuffers[i] = outBuf
            }

            if cancelled.pointee { break }

            nonisolated(unsafe) let screenBufs = batchScreenBuffers
            nonisolated(unsafe) let webcamBufs = batchWebcamBuffers
            nonisolated(unsafe) let outBufs = outputBuffers
            let times = batchTimes

            DispatchQueue.concurrentPerform(iterations: batchCount) { i in
              guard let screenBuf = screenBufs[i],
                let outputBuf = outBufs[i]
              else { return }
              CameraVideoCompositor.renderFrame(
                screenBuffer: screenBuf,
                webcamBuffer: webcamBufs[i],
                outputBuffer: outputBuf,
                compositionTime: times[i],
                instruction: instruction
              )
            }

            for i in 0..<batchCount {
              guard let outputBuf = outputBuffers[i] else { continue }
              frameWriter.submit(
                index: batchStart + i,
                buffer: outputBuf,
                time: batchTimes[i]
              )
            }

            batchScreenSamples.removeAll()
            batchWebcamSamples.removeAll()
          }

          frameWriter.finish()
          frameWriter.waitUntilDone()
          pipelineVideoInput.markAsFinished()
          pipelineReader.cancelReading()

          audioGroup.wait()

          if cancelled.pointee {
            pipelineWriter.cancelWriting()
            try? FileManager.default.removeItem(at: outputURL)
            cont.resume(throwing: CancellationError())
            return
          }

          pipelineWriter.finishWriting {
            if pipelineWriter.status == .failed {
              cont.resume(
                throwing: pipelineWriter.error
                  ?? CaptureError.recordingFailed("Export writing failed")
              )
            } else {
              logger.info("Parallel render export completed (\(coreCount) cores)")
              if let handler = progressHandler {
                Task { @MainActor in handler(1.0, nil) }
              }
              cont.resume()
            }
          }
        }
      }
    } onCancel: {
      cancelled.pointee = true
    }
  }

  private static func gifExport(
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
            cont.resume(throwing: CaptureError.recordingFailed("Failed to create pixel buffer pool for GIF"))
            return
          }

          let rgbaBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(width) * Int(height) * 4)
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
              if CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(next)) <= outputSeconds + 0.001 {
                latestScreenSample = next
                nextScreenSample = pipelineScreenOutput.copyNextSampleBuffer()
              } else {
                break
              }
            }

            if pipelineWebcamOutput != nil {
              while let next = nextWebcamSample {
                if CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(next)) <= outputSeconds + 0.001 {
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

            var outBuf: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &outBuf)
            guard let outputBuffer = outBuf else { continue }

            CameraVideoCompositor.renderFrame(
              screenBuffer: screenBuffer,
              webcamBuffer: webcamBuffer,
              outputBuffer: outputBuffer,
              compositionTime: outputTime,
              instruction: instruction
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
              cont.resume(throwing: CaptureError.recordingFailed("gifski_add_frame failed: \(addResult)"))
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
            cont.resume(throwing: CaptureError.recordingFailed("gifski_finish failed: \(finishResult)"))
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

  private static func backgroundColorTuples(
    for style: BackgroundStyle
  ) -> [(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)] {
    switch style {
    case .none:
      return []
    case .gradient(let id):
      guard let preset = GradientPresets.preset(for: id) else { return [] }
      return preset.cgColors.map { color in
        let components = color.components ?? [0, 0, 0, 1]
        if components.count >= 4 {
          return (r: components[0], g: components[1], b: components[2], a: components[3])
        } else if components.count >= 2 {
          return (r: components[0], g: components[0], b: components[0], a: components[1])
        }
        return (r: 0, g: 0, b: 0, a: 1)
      }
    case .solidColor(let color):
      return [(r: color.r, g: color.g, b: color.b, a: color.a)]
    case .image:
      return []
    }
  }

  private static func addAudioTracks(
    to composition: AVMutableComposition,
    sources: [AudioSource],
    videoTrimRange: CMTimeRange
  ) async throws {
    for source in sources {
      let asset = AVURLAsset(url: source.url)
      guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else { continue }

      let compTrack = composition.addMutableTrack(
        withMediaType: .audio,
        preferredTrackID: kCMPersistentTrackID_Invalid
      )

      for region in source.regions {
        let overlapStart = CMTimeMaximum(region.start, videoTrimRange.start)
        let overlapEnd = CMTimeMinimum(region.end, videoTrimRange.end)
        guard CMTimeCompare(overlapEnd, overlapStart) > 0 else { continue }

        let sourceRange = CMTimeRange(start: overlapStart, end: overlapEnd)
        let insertionTime = CMTimeSubtract(overlapStart, videoTrimRange.start)

        try compTrack?.insertTimeRange(sourceRange, of: audioTrack, at: insertionTime)
      }
    }
  }

  private static func buildAudioMix(
    for composition: AVComposition,
    sources: [AudioSource]
  ) -> AVMutableAudioMix? {
    let audioTracks = composition.tracks(withMediaType: .audio)
    guard !audioTracks.isEmpty else { return nil }

    let needsMix = sources.contains { $0.volume != 1.0 }
    guard needsMix else { return nil }

    let mix = AVMutableAudioMix()
    var params: [AVMutableAudioMixInputParameters] = []

    for (index, track) in audioTracks.enumerated() {
      guard index < sources.count else { break }
      let source = sources[index]
      let inputParams = AVMutableAudioMixInputParameters(track: track)
      inputParams.trackID = track.trackID
      inputParams.setVolume(source.volume, at: .zero)
      params.append(inputParams)
    }

    mix.inputParameters = params
    return mix
  }
}
