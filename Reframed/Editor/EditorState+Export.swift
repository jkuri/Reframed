import AVFoundation
import CoreMedia
import Foundation

extension EditorState {
  func export(settings: ExportSettings) async throws -> URL {
    isExporting = true
    exportProgress = 0
    exportETA = nil
    exportStatusMessage = nil
    defer {
      isExporting = false
      exportTask = nil
      exportStatusMessage = nil
    }

    if isMicProcessing {
      exportStatusMessage =
        "Waiting for noise reduction… \(Int(micProcessingProgress * 100))%"
      while isMicProcessing {
        try await Task.sleep(for: .milliseconds(100))
        exportStatusMessage =
          "Waiting for noise reduction… \(Int(micProcessingProgress * 100))%"
      }
      exportStatusMessage = nil
    }

    let cursorSnapshot = showCursor ? activeCursorProvider?.makeSnapshot() : nil

    let sysRegions = systemAudioRegions.map {
      CMTimeRange(
        start: CMTime(seconds: $0.startSeconds, preferredTimescale: 600),
        end: CMTime(seconds: $0.endSeconds, preferredTimescale: 600)
      )
    }
    let micRegions = micAudioRegions.map {
      CMTimeRange(
        start: CMTime(seconds: $0.startSeconds, preferredTimescale: 600),
        end: CMTime(seconds: $0.endSeconds, preferredTimescale: 600)
      )
    }
    let camFsRegions = cameraRegions.filter { $0.type == .fullscreen }.map {
      RegionTransitionInfo(
        timeRange: CMTimeRange(
          start: CMTime(seconds: $0.startSeconds, preferredTimescale: 600),
          end: CMTime(seconds: $0.endSeconds, preferredTimescale: 600)
        ),
        entryTransition: $0.entryTransition ?? .none,
        entryDuration: $0.entryTransitionDuration ?? 0.3,
        exitTransition: $0.exitTransition ?? .none,
        exitDuration: $0.exitTransitionDuration ?? 0.3
      )
    }
    let camHiddenRegions = cameraRegions.filter { $0.type == .hidden }.map {
      RegionTransitionInfo(
        timeRange: CMTimeRange(
          start: CMTime(seconds: $0.startSeconds, preferredTimescale: 600),
          end: CMTime(seconds: $0.endSeconds, preferredTimescale: 600)
        ),
        entryTransition: $0.entryTransition ?? .none,
        entryDuration: $0.entryTransitionDuration ?? 0.3,
        exitTransition: $0.exitTransition ?? .none,
        exitDuration: $0.exitTransitionDuration ?? 0.3
      )
    }
    let camCustomRegions: [CameraCustomRegion] =
      cameraRegions
      .filter { $0.type == .custom && $0.customLayout != nil }
      .map {
        CameraCustomRegion(
          timeRange: CMTimeRange(
            start: CMTime(seconds: $0.startSeconds, preferredTimescale: 600),
            end: CMTime(seconds: $0.endSeconds, preferredTimescale: 600)
          ),
          layout: $0.customLayout!,
          cameraAspect: $0.customCameraAspect ?? cameraAspect,
          cornerRadius: $0.customCornerRadius ?? cameraCornerRadius,
          shadow: $0.customShadow ?? cameraShadow,
          borderWidth: $0.customBorderWidth ?? cameraBorderWidth,
          borderColor: ($0.customBorderColor ?? cameraBorderColor).cgColor,
          mirrored: $0.customMirrored ?? cameraMirrored,
          entryTransition: $0.entryTransition ?? .none,
          entryDuration: $0.entryTransitionDuration ?? 0.3,
          exitTransition: $0.exitTransition ?? .none,
          exitDuration: $0.exitTransitionDuration ?? 0.3
        )
      }

    let trimStartSec = CMTimeGetSeconds(trimStart)
    let trimEndSec = CMTimeGetSeconds(trimEnd)
    let isSingleFullRange =
      videoRegions.count == 1
      && abs(videoRegions[0].startSeconds - trimStartSec) < 0.01
      && abs(videoRegions[0].endSeconds - trimEndSec) < 0.01
      && (videoRegions[0].entryTransition ?? RegionTransitionType.none) == RegionTransitionType.none
      && (videoRegions[0].exitTransition ?? RegionTransitionType.none) == RegionTransitionType.none

    let vidRegions: [RegionTransitionInfo] =
      isSingleFullRange
      ? []
      : videoRegions.map {
        RegionTransitionInfo(
          timeRange: CMTimeRange(
            start: CMTime(seconds: $0.startSeconds, preferredTimescale: 600),
            end: CMTime(seconds: $0.endSeconds, preferredTimescale: 600)
          ),
          entryTransition: $0.entryTransition ?? .none,
          entryDuration: $0.entryTransitionDuration ?? 0.3,
          exitTransition: $0.exitTransition ?? .none,
          exitDuration: $0.exitTransitionDuration ?? 0.3
        )
      }

    let exportResult: RecordingResult
    if webcamEnabled {
      exportResult = result
    } else {
      exportResult = RecordingResult(
        screenVideoURL: result.screenVideoURL,
        webcamVideoURL: nil,
        systemAudioURL: result.systemAudioURL,
        microphoneAudioURL: result.microphoneAudioURL,
        cursorMetadataURL: result.cursorMetadataURL,
        screenSize: result.screenSize,
        webcamSize: nil,
        fps: result.fps,
        captureQuality: result.captureQuality
      )
    }

    let state = self
    let url = try await VideoCompositor.export(
      result: exportResult,
      cameraLayout: cameraLayout,
      cameraAspect: cameraAspect,
      trimRange: vidRegions.isEmpty
        ? CMTimeRange(start: trimStart, end: trimEnd)
        : CMTimeRange(start: .zero, end: duration),
      systemAudioRegions: sysRegions.isEmpty ? nil : sysRegions,
      micAudioRegions: micRegions.isEmpty ? nil : micRegions,
      cameraFullscreenRegions: camFsRegions.isEmpty ? nil : camFsRegions,
      cameraHiddenRegions: camHiddenRegions.isEmpty ? nil : camHiddenRegions,
      cameraCustomRegions: camCustomRegions.isEmpty ? nil : camCustomRegions,
      videoRegions: vidRegions.isEmpty ? nil : vidRegions,
      backgroundStyle: backgroundStyle,
      backgroundImageURL: backgroundImageURL(),
      backgroundImageFillMode: backgroundImageFillMode,
      canvasAspect: canvasAspect,
      padding: padding,
      videoCornerRadius: videoCornerRadius,
      cameraCornerRadius: cameraCornerRadius,
      cameraBorderWidth: cameraBorderWidth,
      cameraBorderColor: cameraBorderColor,
      videoShadow: videoShadow,
      cameraShadow: cameraShadow,
      cameraMirrored: cameraMirrored,
      cameraFullscreenFillMode: cameraFullscreenFillMode,
      cameraFullscreenAspect: cameraFullscreenAspect,
      exportSettings: settings,
      cursorSnapshot: cursorSnapshot,
      cursorStyle: cursorStyle,
      cursorSize: cursorSize,
      cursorFillColor: cursorFillColor,
      cursorStrokeColor: cursorStrokeColor,
      showClickHighlights: showClickHighlights,
      clickHighlightColor: clickHighlightColor.cgColor,
      clickHighlightSize: clickHighlightSize,
      zoomFollowCursor: zoomFollowCursor,
      zoomTimeline: zoomTimeline,
      systemAudioVolume: effectiveSystemAudioVolume,
      micAudioVolume: effectiveMicAudioVolume,
      micNoiseReductionEnabled: micNoiseReductionEnabled,
      micNoiseReductionIntensity: micNoiseReductionIntensity,
      cameraBackgroundStyle: cameraBackgroundStyle,
      cameraBackgroundImageURL: cameraBackgroundImageURL(),
      processedMicAudioURL: processedMicAudioURL,
      progressHandler: { progress, eta in
        state.exportProgress = progress
        state.exportETA = eta
      }
    )
    exportProgress = 1.0
    lastExportedURL = url
    logger.info("Export finished: \(url.path)")
    return url
  }

  func cancelExport() {
    exportTask?.cancel()
    exportTask = nil
  }
}
