import CoreMedia
import SwiftUI

extension EditorView {
  var videoPreview: some View {
    let screenSize = editorState.result.screenSize
    let hasNonDefaultBg: Bool = {
      switch editorState.backgroundStyle {
      case .none: return false
      case .solidColor: return true
      case .gradient, .image: return true
      }
    }()
    let hasEffects =
      hasNonDefaultBg || editorState.canvasAspect != .original
      || editorState.padding > 0 || editorState.videoCornerRadius > 0
      || editorState.videoShadow > 0
    let canvasAspect: CGFloat = {
      let canvas = editorState.canvasSize(for: screenSize)
      return canvas.width / max(canvas.height, 1)
    }()

    return GeometryReader { geo in
      ZStack {
        if hasEffects {
          backgroundView
        }

        VideoPreviewView(
          screenPlayer: editorState.playerController.screenPlayer,
          webcamPlayer: editorState.webcamEnabled ? editorState.playerController.webcamPlayer : nil,
          cameraLayout: effectiveCameraLayoutBinding,
          defaultPipLayout: editorState.cameraLayout,
          defaultPipCameraAspect: editorState.cameraAspect,
          defaultPipCornerRadius: editorState.cameraCornerRadius,
          defaultPipBorderWidth: editorState.cameraBorderWidth,
          defaultPipBorderColor: editorState.cameraBorderColor.cgColor,
          defaultPipShadow: editorState.cameraShadow,
          defaultPipMirrored: editorState.cameraMirrored,
          webcamSize: editorState.webcamEnabled ? editorState.result.webcamSize : nil,
          screenSize: screenSize,
          canvasSize: editorState.canvasSize(for: screenSize),
          padding: editorState.padding,
          videoCornerRadius: editorState.videoCornerRadius,
          cameraAspect: editorState.cameraAspect,
          cameraCornerRadius: editorState.cameraCornerRadius,
          cameraBorderWidth: editorState.cameraBorderWidth,
          cameraBorderColor: editorState.cameraBorderColor.cgColor,
          videoShadow: editorState.videoShadow,
          cameraShadow: editorState.cameraShadow,
          cameraMirrored: editorState.cameraMirrored,
          cursorMetadataProvider: editorState.activeCursorProvider,
          showCursor: editorState.showCursor,
          cursorStyle: editorState.cursorStyle,
          cursorSize: editorState.cursorSize,
          cursorFillColor: editorState.cursorFillColor,
          cursorStrokeColor: editorState.cursorStrokeColor,
          showClickHighlights: editorState.showClickHighlights,
          clickHighlightColor: editorState.clickHighlightColor.cgColor,
          clickHighlightSize: editorState.clickHighlightSize,
          useSystemCursor: editorState.useSystemCursor,
          cursorSway: editorState.cursorSway,
          cursorMotionBlur: editorState.cursorMotionBlur,
          clickBounce: editorState.clickBounce,
          zoomFollowCursor: editorState.zoomFollowCursor,
          currentTime: CMTimeGetSeconds(editorState.currentTime),
          zoomTimeline: editorState.zoomTimeline,
          cameraFullscreenRegions: editorState.webcamEnabled
            ? editorState.cameraRegions.filter { $0.type == .fullscreen }.map { r in
              (
                start: r.startSeconds, end: r.endSeconds,
                entryTransition: r.entryTransition ?? .none,
                entryDuration: r.entryTransitionDuration ?? 0.3,
                exitTransition: r.exitTransition ?? .none,
                exitDuration: r.exitTransitionDuration ?? 0.3
              )
            } : [],
          cameraHiddenRegions: editorState.webcamEnabled
            ? editorState.cameraRegions.filter { $0.type == .hidden }.map { r in
              (
                start: r.startSeconds, end: r.endSeconds,
                entryTransition: r.entryTransition ?? .none,
                entryDuration: r.entryTransitionDuration ?? 0.3,
                exitTransition: r.exitTransition ?? .none,
                exitDuration: r.exitTransitionDuration ?? 0.3
              )
            } : [],
          cameraCustomRegions: editorState.webcamEnabled
            ? editorState.cameraRegions.filter { $0.type == .custom && $0.customLayout != nil }
              .map { r in
                (
                  start: r.startSeconds,
                  end: r.endSeconds,
                  layout: r.customLayout!,
                  cameraAspect: r.customCameraAspect ?? editorState.cameraAspect,
                  cornerRadius: r.customCornerRadius ?? editorState.cameraCornerRadius,
                  shadow: r.customShadow ?? editorState.cameraShadow,
                  borderWidth: r.customBorderWidth ?? editorState.cameraBorderWidth,
                  borderColor: (r.customBorderColor ?? editorState.cameraBorderColor).cgColor,
                  mirrored: r.customMirrored ?? editorState.cameraMirrored,
                  entryTransition: r.entryTransition ?? .none,
                  entryDuration: r.entryTransitionDuration ?? 0.3,
                  exitTransition: r.exitTransition ?? .none,
                  exitDuration: r.exitTransitionDuration ?? 0.3
                )
              } : [],
          cameraFullscreenFillMode: editorState.cameraFullscreenFillMode,
          cameraFullscreenAspect: editorState.cameraFullscreenAspect,
          videoRegions: editorState.videoRegions.map { r in
            (
              start: r.startSeconds, end: r.endSeconds,
              entryTransition: r.entryTransition ?? .none,
              entryDuration: r.entryTransitionDuration ?? 0.3,
              exitTransition: r.exitTransition ?? .none,
              exitDuration: r.exitTransitionDuration ?? 0.3
            )
          },
          isPreviewMode: editorState.isPreviewMode,
          isPlaying: editorState.isPlaying,
          clickSoundEnabled: editorState.clickSoundEnabled && editorState.showCursor
            && editorState.cursorMetadataProvider != nil,
          clickSoundVolume: editorState.clickSoundVolume,
          clickSoundStyle: editorState.clickSoundStyle,
          spotlightEnabled: editorState.isSpotlightActive(at: CMTimeGetSeconds(editorState.currentTime))
            && editorState.showCursor && editorState.cursorMetadataProvider != nil,
          spotlightRadius: editorState.effectiveSpotlightSettings(
            at: CMTimeGetSeconds(editorState.currentTime)
          ).radius,
          spotlightDimOpacity: editorState.effectiveSpotlightSettings(
            at: CMTimeGetSeconds(editorState.currentTime)
          ).dimOpacity,
          spotlightEdgeSoftness: editorState.effectiveSpotlightSettings(
            at: CMTimeGetSeconds(editorState.currentTime)
          ).edgeSoftness,
          cameraBackgroundStyle: editorState.webcamEnabled ? editorState.cameraBackgroundStyle : .none,
          cameraBackgroundImage: editorState.cameraBackgroundImage,
          isHDR: editorState.result.isHDR
        )

        if let captionText = editorState.visibleCaptionText(
          at: CMTimeGetSeconds(editorState.currentTime)
        ) {
          CaptionOverlayView(
            text: captionText,
            position: editorState.captionPosition,
            fontSize: editorState.captionFontSize,
            fontWeight: editorState.captionFontWeight,
            textColor: editorState.captionTextColor,
            backgroundColor: editorState.captionBackgroundColor,
            backgroundOpacity: editorState.captionBackgroundOpacity,
            showBackground: editorState.captionShowBackground,
            screenWidth: editorState.result.screenSize.width,
            onDrag: { relX, relY in
              editorState.captionPosition = CaptionPosition(relativeX: relX, relativeY: relY)
            },
            onDragEnd: {
              editorState.scheduleSave()
              editorState.history.pushSnapshot(editorState.createSnapshot())
            }
          )
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .aspectRatio(hasEffects ? canvasAspect : screenSize.width / max(screenSize.height, 1), contentMode: .fit)
      .clipShape(RoundedRectangle(cornerRadius: Radius.xxl))
      .overlay(
        RoundedRectangle(cornerRadius: Radius.xxl)
          .strokeBorder(ReframedColors.border, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
  }

  @ViewBuilder
  var backgroundView: some View {
    switch editorState.backgroundStyle {
    case .none:
      Color.black
    case .gradient(let id):
      if let preset = GradientPresets.preset(for: id) {
        LinearGradient(
          colors: preset.colors,
          startPoint: preset.startPoint,
          endPoint: preset.endPoint
        )
      } else {
        Color.clear
      }
    case .solidColor(let codableColor):
      Color(cgColor: codableColor.cgColor)
    case .image:
      if let nsImage = editorState.backgroundImage {
        GeometryReader { geo in
          Image(nsImage: nsImage)
            .resizable()
            .aspectRatio(contentMode: editorState.backgroundImageFillMode == .fill ? .fill : .fit)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
      } else {
        Color.black
      }
    }
  }

  var effectiveCameraLayoutBinding: Binding<CameraLayout> {
    let currentTime = CMTimeGetSeconds(editorState.currentTime)
    if let regionId = editorState.activeCameraRegionId(at: currentTime) {
      return Binding(
        get: { editorState.effectiveCameraLayout(at: currentTime) },
        set: { newLayout in
          editorState.updateCameraRegionLayout(regionId: regionId, layout: newLayout)
          editorState.clampCameraRegionLayout(regionId: regionId)
        }
      )
    }
    return $editorState.cameraLayout
  }
}
