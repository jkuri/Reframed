import SwiftUI

enum TrimEdge {
  case leading, trailing
}

struct TrimHandle: View {
  let edge: TrimEdge
  let position: Double
  let totalWidth: CGFloat
  let height: CGFloat
  let onDrag: (Double) -> Void

  static let handleWidth: CGFloat = 12
  private let hitWidth: CGFloat = 28

  var body: some View {
    Rectangle()
      .fill(Color.clear)
      .frame(width: hitWidth, height: height)
      .contentShape(Rectangle())
      .onContinuousHover { phase in
        switch phase {
        case .active:
          NSCursor.resizeLeftRight.set()
        case .ended:
          NSCursor.arrow.set()
        @unknown default:
          break
        }
      }
      .position(x: positionX, y: height / 2)
      .highPriorityGesture(
        DragGesture(minimumDistance: 0, coordinateSpace: .named("timeline"))
          .onChanged { value in
            let fraction = max(0, min(1, value.location.x / totalWidth))
            onDrag(fraction)
          }
      )
  }

  private var positionX: CGFloat {
    let x = totalWidth * position
    return edge == .leading ? x - Self.handleWidth / 2 : x + Self.handleWidth / 2
  }
}
