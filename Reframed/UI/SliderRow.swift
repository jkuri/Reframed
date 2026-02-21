import SwiftUI

struct SliderRow<V: BinaryFloatingPoint>: View where V.Stride: BinaryFloatingPoint {
  var label: String? = nil
  var labelWidth: CGFloat? = nil
  @Binding var value: V
  let range: ClosedRange<V>
  var step: V.Stride = 1
  var formattedValue: String? = nil
  var valueWidth: CGFloat = 36

  var body: some View {
    HStack(spacing: 8) {
      if let label {
        if let labelWidth {
          Text(label)
            .font(.system(size: 12))
            .foregroundStyle(ReframedColors.secondaryText)
            .frame(width: labelWidth, alignment: .leading)
        } else {
          Text(label)
            .font(.system(size: 12))
            .foregroundStyle(ReframedColors.secondaryText)
        }
      }
      MonoSlider(value: $value, range: range, step: step)
      if let formattedValue {
        Text(formattedValue)
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(width: valueWidth, alignment: .trailing)
      }
    }
  }
}

struct MonoSlider<V: BinaryFloatingPoint>: View where V.Stride: BinaryFloatingPoint {
  @Binding var value: V
  let range: ClosedRange<V>
  var step: V.Stride = 1
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.isEnabled) private var isEnabled

  private let trackHeight: CGFloat = 6
  private let thumbSize: CGFloat = 16
  private let thumbBorder: CGFloat = 1.5

  private var fraction: CGFloat {
    let span = CGFloat(range.upperBound - range.lowerBound)
    guard span > 0 else { return 0 }
    return CGFloat(value - range.lowerBound) / span
  }

  var body: some View {
    let _ = colorScheme
    GeometryReader { geo in
      let w = geo.size.width
      let usable = w - thumbSize
      let thumbX = thumbSize / 2 + usable * fraction

      ZStack(alignment: .leading) {
        Capsule()
          .fill(ReframedColors.muted)
          .frame(height: trackHeight)

        Capsule()
          .fill(ReframedColors.primary.opacity(isEnabled ? 1 : 0.5))
          .frame(width: max(0, thumbX), height: trackHeight)

        Circle()
          .fill(ReframedColors.background)
          .overlay(
            Circle()
              .stroke(ReframedColors.primary, lineWidth: thumbBorder)
          )
          .frame(width: thumbSize, height: thumbSize)
          .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
          .position(x: thumbX, y: geo.size.height / 2)
      }
      .frame(height: geo.size.height)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { drag in
            let raw = (drag.location.x - thumbSize / 2) / usable
            let clamped = max(0, min(1, raw))
            let continuous = V(clamped) * (range.upperBound - range.lowerBound) + range.lowerBound
            if step > 0 {
              let stepped = (continuous - range.lowerBound) / V(step)
              value = min(range.upperBound, range.lowerBound + V(stepped.rounded()) * V(step))
            } else {
              value = continuous
            }
          }
      )
    }
    .frame(height: thumbSize)
  }
}
