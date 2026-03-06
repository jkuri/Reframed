import AVFoundation
import CoreMedia
import Foundation

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
      videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_64RGBAHalf]
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

    let videoSettings = EncodingSettings.exportVideoSettings(
      codec: codec,
      width: Int(renderSize.width),
      height: Int(renderSize.height),
      fps: Int(exportFPS)
    )
    nonisolated(unsafe) let videoInput = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: videoSettings
    )
    videoInput.expectsMediaDataInRealTime = false
    writer.add(videoInput)

    nonisolated(unsafe) var audioInput: AVAssetWriterInput?
    if audioOutput != nil {
      let aInput = AVAssetWriterInput(
        mediaType: .audio,
        outputSettings: EncodingSettings.aacAudioSettings(bitrate: audioBitrate)
      )
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
}
