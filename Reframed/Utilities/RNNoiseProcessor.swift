@preconcurrency import AVFoundation
import Foundation
import RNNoise

private struct ChunkParams: @unchecked Sendable {
  let input: UnsafeMutablePointer<Float>
  let output: UnsafeMutablePointer<Float>
  let warmupStart: Int
  let outputStart: Int
  let outputEnd: Int
  let tracker: RNNoiseProgressTracker
}

private actor RNNoiseProgressTracker {
  let total: Int
  var completed: Int = 0
  let onProgress: (@MainActor @Sendable (Double) -> Void)?

  init(total: Int, onProgress: (@MainActor @Sendable (Double) -> Void)?) {
    self.total = total
    self.onProgress = onProgress
  }

  func add(_ count: Int) async {
    completed += count
    if let onProgress {
      let p = min(1.0, Double(completed) / Double(total))
      await onProgress(p)
    }
  }
}

enum RNNoiseProcessor {
  private static let frameSize = 480
  private static let overlapFrames = 20

  static func processFile(
    inputURL: URL,
    outputURL: URL,
    intensity: Float = 0.5,
    onProgress: (@MainActor @Sendable (Double) -> Void)? = nil
  ) async throws {
    let sourceFile = try AVAudioFile(forReading: inputURL)
    let sourceFormat = sourceFile.processingFormat
    let totalFrames = AVAudioFrameCount(sourceFile.length)

    let monoFormat = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: 48000,
      channels: 1,
      interleaved: false
    )!

    let conversionProgress: (@MainActor @Sendable (Double) -> Void)?
    if let onProgress {
      conversionProgress = { p in onProgress(p * 0.05) }
    } else {
      conversionProgress = nil
    }

    let convertedBuffer = try convertToMono48k(
      sourceFile: sourceFile,
      sourceFormat: sourceFormat,
      monoFormat: monoFormat,
      totalFrames: totalFrames,
      onProgress: conversionProgress
    )

    let sampleCount = Int(convertedBuffer.frameLength)
    guard sampleCount > 0, let channelData = convertedBuffer.floatChannelData?[0] else {
      throw CaptureError.recordingFailed("No audio data after conversion")
    }

    let clamped = max(0, min(1, intensity))
    let passes: Int
    let wet: Float
    if clamped <= 0.5 {
      passes = 1
      wet = clamped * 2.0
    } else {
      passes = 2
      wet = 1.0
    }
    let dry = 1.0 - wet

    let inputPointer = UnsafeMutablePointer<Float>.allocate(capacity: sampleCount)
    memcpy(inputPointer, channelData, sampleCount * MemoryLayout<Float>.size)

    var currentInput = inputPointer
    var outputSamples: UnsafeMutablePointer<Float>? = nil

    do {
      for pass in 0..<passes {
        let isLastPass = pass == passes - 1

        let passProgress: (@MainActor @Sendable (Double) -> Void)?
        if let onProgress {
          let passIndex = pass
          let totalPasses = passes
          passProgress = { p in
            let base = 0.05 + (0.80 * Double(passIndex) / Double(totalPasses))
            let addition = (0.80 / Double(totalPasses)) * p
            onProgress(base + addition)
          }
        } else {
          passProgress = nil
        }

        let passOutput = try await processParallel(
          input: currentInput,
          sampleCount: sampleCount,
          onProgress: passProgress
        )

        if isLastPass && dry > 0 {
          for i in 0..<sampleCount {
            passOutput[i] = dry * channelData[i] + wet * passOutput[i]
          }
        }

        if pass > 0 {
          currentInput.deallocate()
        }
        currentInput = passOutput
        outputSamples = passOutput
      }
    } catch {
      if currentInput != inputPointer { currentInput.deallocate() }
      inputPointer.deallocate()
      throw error
    }
    inputPointer.deallocate()

    guard let outputSamples else {
      throw CaptureError.recordingFailed("No output from noise reduction")
    }

    let outputBuffer = AVAudioPCMBuffer(
      pcmFormat: monoFormat,
      frameCapacity: AVAudioFrameCount(sampleCount)
    )!
    outputBuffer.frameLength = AVAudioFrameCount(sampleCount)
    memcpy(outputBuffer.floatChannelData![0], outputSamples, sampleCount * MemoryLayout<Float>.size)
    outputSamples.deallocate()

    let stereoFormat = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: 48000,
      channels: 2,
      interleaved: false
    )!
    let stereoBuffer = AVAudioPCMBuffer(
      pcmFormat: stereoFormat,
      frameCapacity: AVAudioFrameCount(sampleCount)
    )!
    stereoBuffer.frameLength = AVAudioFrameCount(sampleCount)
    let monoData = outputBuffer.floatChannelData![0]
    memcpy(stereoBuffer.floatChannelData![0], monoData, sampleCount * MemoryLayout<Float>.size)
    memcpy(stereoBuffer.floatChannelData![1], monoData, sampleCount * MemoryLayout<Float>.size)

    let outputSettings: [String: Any] = [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: 48000.0,
      AVNumberOfChannelsKey: 2,
      AVEncoderBitRateKey: 320_000,
    ]

    let outputFile = try AVAudioFile(forWriting: outputURL, settings: outputSettings)
    let chunkFrames: AVAudioFrameCount = 48000
    let totalOutputFrames = stereoBuffer.frameLength
    var written: AVAudioFrameCount = 0

    while written < totalOutputFrames {
      let remaining = totalOutputFrames - written
      let count = min(chunkFrames, remaining)

      let chunk = AVAudioPCMBuffer(pcmFormat: stereoFormat, frameCapacity: count)!
      chunk.frameLength = count
      memcpy(
        chunk.floatChannelData![0],
        stereoBuffer.floatChannelData![0].advanced(by: Int(written)),
        Int(count) * MemoryLayout<Float>.size
      )
      memcpy(
        chunk.floatChannelData![1],
        stereoBuffer.floatChannelData![1].advanced(by: Int(written)),
        Int(count) * MemoryLayout<Float>.size
      )

      try outputFile.write(from: chunk)
      written += count

      if let onProgress {
        let p = 0.85 + 0.15 * Double(written) / Double(totalOutputFrames)
        await onProgress(p)
      }
    }
  }

  private static func processParallel(
    input: UnsafeMutablePointer<Float>,
    sampleCount: Int,
    onProgress: (@MainActor @Sendable (Double) -> Void)?
  ) async throws -> UnsafeMutablePointer<Float> {

    let coreCount = max(1, ProcessInfo.processInfo.activeProcessorCount - 1)
    let chunkCount = min(coreCount, max(1, sampleCount / (frameSize * 100)))
    let baseSamplesPerChunk = sampleCount / chunkCount
    let overlapSamples = overlapFrames * frameSize

    let output = UnsafeMutablePointer<Float>.allocate(capacity: sampleCount)
    let tracker = RNNoiseProgressTracker(total: sampleCount, onProgress: onProgress)

    try await withThrowingTaskGroup(of: Void.self) { group in
      for chunkIdx in 0..<chunkCount {
        let outputStart = chunkIdx * baseSamplesPerChunk
        let outputEnd: Int
        if chunkIdx == chunkCount - 1 {
          outputEnd = sampleCount
        } else {
          outputEnd = (chunkIdx + 1) * baseSamplesPerChunk
        }
        let warmupStart = max(0, outputStart - overlapSamples)

        let params = ChunkParams(
          input: input,
          output: output,
          warmupStart: warmupStart,
          outputStart: outputStart,
          outputEnd: outputEnd,
          tracker: tracker
        )

        group.addTask {
          guard let state = rnnoise_create(nil) else { return }
          defer { rnnoise_destroy(state) }

          var inFrame = [Float](repeating: 0, count: frameSize)
          var outFrame = [Float](repeating: 0, count: frameSize)
          let scale: Float = 32768.0
          let invScale: Float = 1.0 / 32768.0

          var offset = params.warmupStart
          var samplesSinceReport = 0

          while offset < params.outputEnd {
            try Task.checkCancellation()

            let remaining = params.outputEnd - offset
            let count = min(remaining, frameSize)

            for i in 0..<count {
              inFrame[i] = params.input[offset + i] * scale
            }
            for i in count..<frameSize {
              inFrame[i] = 0
            }

            _ = rnnoise_process_frame(state, &outFrame, inFrame)

            if offset >= params.outputStart {
              for i in 0..<count {
                params.output[offset + i] = outFrame[i] * invScale
              }
              samplesSinceReport += count
            }

            offset += count

            if samplesSinceReport >= 48000 {
              await params.tracker.add(samplesSinceReport)
              samplesSinceReport = 0
            }
          }

          if samplesSinceReport > 0 {
            await params.tracker.add(samplesSinceReport)
          }
        }
      }
      try await group.waitForAll()
    }

    return output
  }

  private static func convertToMono48k(
    sourceFile: AVAudioFile,
    sourceFormat: AVAudioFormat,
    monoFormat: AVAudioFormat,
    totalFrames: AVAudioFrameCount,
    onProgress: (@MainActor @Sendable (Double) -> Void)?
  ) throws -> AVAudioPCMBuffer {
    let converter = AVAudioConverter(from: sourceFormat, to: monoFormat)!
    let readBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: 4096)!
    let capacity =
      AVAudioFrameCount(
        Double(totalFrames) * 48000.0 / sourceFormat.sampleRate
      ) + 4096
    let convertBuffer = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: capacity)!

    nonisolated(unsafe) let unsafeReadBuffer = readBuffer
    nonisolated(unsafe) var inputDone = false
    nonisolated(unsafe) var framesRead: AVAudioFrameCount = 0
    nonisolated(unsafe) var lastReportedProgress: Double = 0

    let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
      if inputDone {
        outStatus.pointee = .endOfStream
        return nil
      }
      do {
        unsafeReadBuffer.frameLength = 0
        try sourceFile.read(into: unsafeReadBuffer)
        if unsafeReadBuffer.frameLength == 0 {
          inputDone = true
          outStatus.pointee = .endOfStream
          return nil
        }

        framesRead += unsafeReadBuffer.frameLength
        if let onProgress {
          let progress = min(1.0, Double(framesRead) / Double(totalFrames))
          if progress - lastReportedProgress >= 0.01 || progress == 1.0 {
            lastReportedProgress = progress
            Task { @MainActor in onProgress(progress) }
          }
        }

        outStatus.pointee = .haveData
        return unsafeReadBuffer
      } catch {
        inputDone = true
        outStatus.pointee = .endOfStream
        return nil
      }
    }

    let status = converter.convert(to: convertBuffer, error: nil, withInputFrom: inputBlock)
    guard status != .error else {
      throw CaptureError.recordingFailed("Failed to convert audio to 48kHz mono")
    }
    return convertBuffer
  }
}
