import AVFoundation
import CoreMedia
import Foundation
import Logging

enum VideoCompositor {
  private static let logger = Logger(label: "eu.jankuri.reframed.video-compositor")

  private struct AudioSource {
    let url: URL
    let regions: [CMTimeRange]
  }

  static func export(
    result: RecordingResult,
    cameraLayout: CameraLayout,
    trimRange: CMTimeRange,
    systemAudioRegions: [CMTimeRange]? = nil,
    micAudioRegions: [CMTimeRange]? = nil,
    cameraFullscreenRegions: [CMTimeRange]? = nil,
    backgroundStyle: BackgroundStyle = .none,
    canvasAspect: CanvasAspect = .original,
    padding: CGFloat = 0,
    videoCornerRadius: CGFloat = 0,
    cameraCornerRadius: CGFloat = 12,
    cameraBorderWidth: CGFloat = 0,
    exportSettings: ExportSettings = ExportSettings(),
    cursorSnapshot: CursorMetadataSnapshot? = nil,
    cursorStyle: CursorStyle = .defaultArrow,
    cursorSize: CGFloat = 24,
    showClickHighlights: Bool = true,
    clickHighlightColor: CGColor = CGColor(srgbRed: 0.2, green: 0.5, blue: 1.0, alpha: 1.0),
    clickHighlightSize: CGFloat = 36,
    zoomFollowCursor: Bool = true,
    zoomTimeline: ZoomTimeline? = nil,
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

    var audioSources: [AudioSource] = []
    if let sysURL = result.systemAudioURL {
      audioSources.append(AudioSource(url: sysURL, regions: systemAudioRegions ?? [effectiveTrim]))
    }
    if let micURL = result.microphoneAudioURL {
      audioSources.append(AudioSource(url: micURL, regions: micAudioRegions ?? [effectiveTrim]))
    }

    let hasVisualEffects =
      backgroundStyle != .none || canvasAspect != .original || padding > 0 || videoCornerRadius > 0
    let hasWebcam = result.webcamVideoURL != nil
    let hasCursor = cursorSnapshot != nil
    let hasZoom = zoomTimeline != nil
    let needsReencode =
      exportSettings.codec != .h264 || exportSettings.resolution != .original
      || exportSettings.fps != .original
    let needsCompositor = hasVisualEffects || hasWebcam || needsReencode || hasCursor || hasZoom

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
          cameraRect = cameraLayout.pixelRect(screenSize: canvasSize, webcamSize: webcamSize)
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

      let scaleX = renderSize.width / canvasSize.width
      let scaleY = renderSize.height / canvasSize.height
      let paddingHPx = padding * screenNaturalSize.width * scaleX
      let paddingVPx = padding * screenNaturalSize.height * scaleY
      let scaledCornerRadius = videoCornerRadius * scaleX

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
        outputSize: renderSize,
        backgroundColors: bgColors,
        backgroundStartPoint: bgStartPoint,
        backgroundEndPoint: bgEndPoint,
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
        }
      )

      let videoComposition = AVMutableVideoComposition()
      videoComposition.customVideoCompositorClass = CameraVideoCompositor.self
      videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(exportFPS))
      videoComposition.renderSize = renderSize
      videoComposition.instructions = [instruction]

      try await addAudioTracks(to: composition, sources: audioSources, videoTrimRange: effectiveTrim)

      let outputURL = FileManager.default.tempRecordingURL()
      try await runManualExport(
        asset: composition,
        videoComposition: videoComposition,
        timeRange: CMTimeRange(start: .zero, duration: effectiveTrim.duration),
        renderSize: renderSize,
        codec: exportSettings.codec.videoCodecType,
        exportFPS: Double(exportFPS),
        to: outputURL,
        fileType: exportSettings.format.fileType,
        progressHandler: progressHandler
      )

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
      reader.add(aOutput)
      audioOutput = aOutput
    }

    nonisolated(unsafe) let writer = try AVAssetWriter(url: url, fileType: fileType)

    let pixels = Double(renderSize.width * renderSize.height)
    let compressionProperties: [String: Any]
    if codec == .hevc {
      compressionProperties = [AVVideoAverageBitRateKey: pixels * exportFPS * 0.04]
    } else {
      compressionProperties = [AVVideoAverageBitRateKey: pixels * exportFPS * 0.06]
    }
    let videoSettings: [String: Any] = [
      AVVideoCodecKey: codec,
      AVVideoWidthKey: Int(renderSize.width),
      AVVideoHeightKey: Int(renderSize.height),
      AVVideoCompressionPropertiesKey: compressionProperties,
    ]
    nonisolated(unsafe) let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    videoInput.expectsMediaDataInRealTime = false
    writer.add(videoInput)

    nonisolated(unsafe) var audioInput: AVAssetWriterInput?
    if audioOutput != nil {
      let audioSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVNumberOfChannelsKey: 2,
        AVSampleRateKey: 44100,
        AVEncoderBitRateKey: 128_000,
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
        let videoQueue = DispatchQueue(label: "eu.jankuri.reframed.export.video")
        let audioQueue = DispatchQueue(label: "eu.jankuri.reframed.export.audio")

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
}
