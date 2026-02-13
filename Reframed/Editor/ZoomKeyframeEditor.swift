import SwiftUI

struct ZoomKeyframeEditor: View {
  let keyframes: [ZoomKeyframe]
  let duration: Double
  let width: CGFloat
  let height: CGFloat
  let onAddKeyframe: (Double) -> Void
  let onRemoveKeyframe: (Int) -> Void

  var body: some View {
    ZStack(alignment: .leading) {
      RoundedRectangle(cornerRadius: 6)
        .fill(ReframedColors.panelBackground)
        .frame(width: width, height: height)

      zoomSpans
      keyframeMarkers
    }
    .frame(width: width, height: height)
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }

  private var zoomSpans: some View {
    Canvas { context, size in
      var i = 0
      while i < keyframes.count - 1 {
        let k0 = keyframes[i]
        let k1 = keyframes[i + 1]

        if k0.zoomLevel > 1.0 || k1.zoomLevel > 1.0 {
          let startX = (k0.t / duration) * size.width
          let endX = (k1.t / duration) * size.width
          let rect = CGRect(x: startX, y: 0, width: max(0, endX - startX), height: size.height)
          context.fill(
            Path(roundedRect: rect, cornerRadius: 2),
            with: .color(ReframedColors.controlAccentColor.opacity(0.2))
          )
        }
        i += 1
      }
    }
    .allowsHitTesting(false)
  }

  private var keyframeMarkers: some View {
    ForEach(Array(keyframes.enumerated()), id: \.offset) { index, keyframe in
      let x = (keyframe.t / duration) * width
      let color: Color = keyframe.isAuto ? .blue : .orange

      Diamond()
        .fill(color)
        .frame(width: 8, height: 8)
        .position(x: x, y: height / 2)
        .contextMenu {
          Button("Remove") {
            onRemoveKeyframe(index)
          }
        }
    }
  }
}

private struct Diamond: Shape {
  func path(in rect: CGRect) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: rect.midX, y: rect.minY))
    p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
    p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
    p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
    p.closeSubpath()
    return p
  }
}
