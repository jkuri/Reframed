import SwiftUI

struct TrimHandle: View {
  let position: Double
  let totalWidth: CGFloat
  let onDrag: (Double) -> Void

  private let handleWidth: CGFloat = 8

  var body: some View {
    RoundedRectangle(cornerRadius: 3)
      .fill(Color.yellow)
      .frame(width: handleWidth, height: 50)
      .offset(x: totalWidth * position - handleWidth / 2)
      .gesture(
        DragGesture(minimumDistance: 1)
          .onChanged { value in
            let fraction = max(0, min(1, value.location.x / totalWidth))
            onDrag(fraction)
          }
      )
  }
}
