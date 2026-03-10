import Foundation
import Logging

extension EditorState {
  var captionAudioURL: URL? {
    switch captionAudioSource {
    case .microphone: processedMicAudioURL ?? result.microphoneAudioURL
    case .system: result.systemAudioURL
    }
  }

  func generateCaptions() {
    guard let audioURL = captionAudioURL else { return }
    guard let model = WhisperModel(rawValue: captionModel) else { return }
    guard let modelPath = WhisperModelManager.shared.modelPath(for: model) else { return }

    transcriptionTask?.cancel()
    isTranscribing = true
    transcriptionProgress = 0
    transcriptionDidFinishEmpty = false

    let language = captionLanguage.whisperCode
    let state = self
    transcriptionTask = Task {
      do {
        var segments = try await TranscriptionService.transcribe(
          audioURL: audioURL,
          model: model,
          modelPath: modelPath,
          language: language,
          onProgress: { progress in
            state.transcriptionProgress = progress
          }
        )
        try Task.checkCancellation()
        segments = Self.filterNonSpeechSegments(segments)
        let driftRatio: Double =
          switch state.captionAudioSource {
          case .microphone: state.playerController.micAudioDriftRatio
          case .system: state.playerController.systemAudioDriftRatio
          }
        if driftRatio != 1.0 {
          segments = segments.map { seg in
            CaptionSegment(
              id: seg.id,
              startSeconds: seg.startSeconds / driftRatio,
              endSeconds: seg.endSeconds / driftRatio,
              text: seg.text,
              words: seg.words?.map { w in
                CaptionWord(
                  word: w.word,
                  startSeconds: w.startSeconds / driftRatio,
                  endSeconds: w.endSeconds / driftRatio
                )
              }
            )
          }
        }
        state.captionSegments = segments
        state.captionsEnabled = !segments.isEmpty
        state.transcriptionDidFinishEmpty = segments.isEmpty
        state.isTranscribing = false
        state.transcriptionProgress = 1.0
        state.scheduleSave()
        state.history.pushSnapshot(state.createSnapshot())
      } catch is CancellationError {
        state.isTranscribing = false
      } catch {
        state.logger.error("Transcription failed: \(error)")
        state.isTranscribing = false
      }
    }
  }

  func cancelTranscription() {
    transcriptionTask?.cancel()
    transcriptionTask = nil
    isTranscribing = false
    transcriptionProgress = 0
  }

  func clearCaptions() {
    captionSegments = []
    captionsEnabled = false
    transcriptionDidFinishEmpty = false
    scheduleSave()
    history.pushSnapshot(createSnapshot())
  }

  func updateSegmentText(_ id: UUID, text: String) {
    guard let idx = captionSegments.firstIndex(where: { $0.id == id }) else { return }
    captionSegments[idx].text = text
    captionSegments[idx].words = nil
    scheduleSave()
    history.pushSnapshot(createSnapshot())
  }

  func deleteSegment(_ id: UUID) {
    captionSegments.removeAll { $0.id == id }
    if captionSegments.isEmpty {
      captionsEnabled = false
    }
    scheduleSave()
    history.pushSnapshot(createSnapshot())
  }

  func captionAtTime(_ time: Double) -> CaptionSegment? {
    FrameRenderer.captionSegmentAt(time: time, in: captionSegments)
  }

  func visibleCaptionText(at time: Double) -> String? {
    guard captionsEnabled, let segment = captionAtTime(time) else { return nil }

    let words: [String]
    if let segmentWords = segment.words, !segmentWords.isEmpty {
      words = segmentWords.map(\.word)
    } else {
      words = segment.text.split(separator: " ").map(String.init)
    }

    guard !words.isEmpty else { return segment.text }

    let maxWords = captionMaxWordsPerLine
    if words.count <= maxWords {
      return words.joined(separator: " ")
    }

    var lines: [String] = []
    var i = 0
    while i < words.count {
      let chunk = words[i..<min(i + maxWords, words.count)]
      lines.append(chunk.joined(separator: " "))
      i += maxWords
    }

    let totalLines = lines.count
    let windowStart = time - segment.startSeconds
    let segmentDuration = segment.endSeconds - segment.startSeconds
    guard segmentDuration > 0 else { return lines.prefix(2).joined(separator: "\n") }

    let linesPerWindow = 2
    let windowCount = max(1, Int(ceil(Double(totalLines) / Double(linesPerWindow))))
    let windowDuration = segmentDuration / Double(windowCount)
    let windowIndex = min(Int(windowStart / windowDuration), windowCount - 1)
    let lineStart = windowIndex * linesPerWindow
    let visibleLines = lines[lineStart..<min(lineStart + linesPerWindow, totalLines)]
    return visibleLines.joined(separator: "\n")
  }

  private static let nonSpeechPattern: Regex = /^\s*[\[\(].*[\]\)]\s*$/

  private static func filterNonSpeechSegments(_ segments: [CaptionSegment]) -> [CaptionSegment] {
    segments.filter { seg in
      let text = seg.text.trimmingCharacters(in: .whitespaces)
      if text.isEmpty { return false }
      if text.wholeMatch(of: nonSpeechPattern) != nil { return false }
      return true
    }
  }
}
