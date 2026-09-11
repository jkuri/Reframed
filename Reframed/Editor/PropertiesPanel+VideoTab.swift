import SwiftUI

extension PropertiesPanel {
  var canvasSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "rectangle.dashed", title: "Canvas")

      SegmentPicker(
        items: CanvasAspect.allCases,
        label: { $0.label },
        selection: $editorState.canvasAspect
      )
      .onChange(of: editorState.canvasAspect) { _, _ in
        editorState.clampCameraPosition()
      }
    }
  }

  var paddingSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      HStack {
        SectionHeader(icon: "arrow.up.left.and.arrow.down.right", title: "Padding")
        Spacer()
        if editorState.padding > 0 {
          Button("Reset") {
            editorState.padding = 0
          }
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.secondaryText)
          .buttonStyle(.plain)
        }
      }

      SliderRow(
        value: $editorState.padding,
        range: 0...0.50,
        step: 0.01,
        formattedValue: "\(Int(editorState.padding * 100))%"
      )
    }
  }

  var cornerRadiusSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      HStack {
        SectionHeader(icon: "rectangle.roundedtop", title: "Corner Radius")
        Spacer()
        if editorState.videoCornerRadius > 0 {
          Button("Reset") {
            editorState.videoCornerRadius = 0
          }
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.secondaryText)
          .buttonStyle(.plain)
        }
      }

      SliderRow(
        value: $editorState.videoCornerRadius,
        range: 0...50,
        formattedValue: "\(Int(editorState.videoCornerRadius))%"
      )
    }
  }

  var videoShadowSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      HStack {
        SectionHeader(icon: "shadow", title: "Shadow")
        Spacer()
        if editorState.videoShadow > 0 {
          Button("Reset") {
            editorState.videoShadow = 0
          }
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.secondaryText)
          .buttonStyle(.plain)
        }
      }

      SliderRow(
        value: $editorState.videoShadow,
        range: 0...100,
        formattedValue: "\(Int(editorState.videoShadow))"
      )
    }
  }

  var speedSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      HStack {
        SectionHeader(icon: "forward.fill", title: "Speed")
        Spacer()
        if editorState.playbackSpeed != 1.0 {
          Button("Reset") {
            editorState.playbackSpeed = 1.0
          }
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.secondaryText)
          .buttonStyle(.plain)
        }
      }

      SegmentPicker(
        items: [1.0, 2.0, 4.0, 8.0],
        label: { "\(Int($0))x" },
        selection: $editorState.playbackSpeed
      )

      SliderRow(
        value: $editorState.playbackSpeed,
        range: TimeLapse.range,
        step: 0.25,
        formattedValue: String(format: "%.2fx", editorState.playbackSpeed),
        valueWidth: 44
      )

      Text(speedFootnote)
        .font(.system(size: FontSize.xxs))
        .foregroundStyle(ReframedColors.secondaryText)
    }
  }

  private var speedFootnote: String {
    let exported = TimeLapse.effectiveDuration(
      seconds: editorState.exportedSourceDuration,
      speed: editorState.playbackSpeed
    )
    let length = "Exports as \(formatDuration(seconds: Int(exported.rounded())))"
    let hasAudio = editorState.hasSystemAudio || editorState.hasMicAudio
    guard hasAudio, TimeLapse.dropsAudio(speed: editorState.playbackSpeed) else { return length }
    return "\(length) · audio removed above 1x"
  }
}
