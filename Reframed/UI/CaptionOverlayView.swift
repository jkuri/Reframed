import CoreMedia
import SwiftUI

struct CaptionOverlayView: View {
  let text: String
  let position: CaptionPosition
  let fontSize: CGFloat
  let fontWeight: CaptionFontWeight
  let textColor: CodableColor
  let backgroundColor: CodableColor
  let backgroundOpacity: CGFloat
  let showBackground: Bool
  let screenWidth: CGFloat
  var onDrag: ((_ relativeX: CGFloat, _ relativeY: CGFloat) -> Void)?
  var onDragEnd: (() -> Void)?

  @State private var dragStartPosition: CaptionPosition?
  @State private var isHovering = false
  @State private var cachedBounds: CaptionBounds = .default

  var body: some View {
    GeometryReader { geo in
      let scaledFontSize = CaptionLayout.scaledFontSize(
        fontSize: fontSize,
        canvasWidth: geo.size.width,
        canvasHeight: geo.size.height,
        screenWidth: screenWidth
      )

      Text(text)
        .font(.system(size: scaledFontSize, weight: fontWeight.swiftUIWeight))
        .foregroundStyle(Color(cgColor: textColor.cgColor))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, scaledFontSize * CaptionLayout.paddingHRatio)
        .padding(.vertical, scaledFontSize * CaptionLayout.paddingVRatio)
        .background {
          if showBackground {
            RoundedRectangle(cornerRadius: scaledFontSize * CaptionLayout.paddingVRatio)
              .fill(Color(cgColor: backgroundColor.cgColor).opacity(backgroundOpacity))
          }
        }
        .frame(maxWidth: geo.size.width * CaptionLayout.maxWidthRatio)
        .position(
          x: geo.size.width * max(cachedBounds.minX, min(cachedBounds.maxX, position.relativeX)),
          y: geo.size.height * max(cachedBounds.minY, min(cachedBounds.maxY, position.relativeY))
        )
        .onHover { hovering in
          isHovering = hovering
          if onDrag != nil && dragStartPosition == nil {
            if hovering {
              NSCursor.openHand.set()
            } else {
              NSCursor.arrow.set()
            }
          }
        }
        .gesture(
          DragGesture(coordinateSpace: .named("captionCanvas"))
            .onChanged { value in
              guard geo.size.width > 0, geo.size.height > 0 else { return }
              if dragStartPosition == nil {
                dragStartPosition = position
                NSCursor.closedHand.set()
              }
              guard let start = dragStartPosition else { return }
              let dx = (value.location.x - value.startLocation.x) / geo.size.width
              let dy = (value.location.y - value.startLocation.y) / geo.size.height
              let relX = max(cachedBounds.minX, min(cachedBounds.maxX, start.relativeX + dx))
              let relY = max(cachedBounds.minY, min(cachedBounds.maxY, start.relativeY + dy))
              onDrag?(relX, relY)
            }
            .onEnded { _ in
              dragStartPosition = nil
              if isHovering {
                NSCursor.openHand.set()
              } else {
                NSCursor.arrow.set()
              }
              onDragEnd?()
            }
        )
        .onChange(of: text) { recomputeBounds(width: geo.size.width, height: geo.size.height) }
        .onChange(of: fontSize) { recomputeBounds(width: geo.size.width, height: geo.size.height) }
        .onChange(of: fontWeight) { recomputeBounds(width: geo.size.width, height: geo.size.height) }
        .onChange(of: geo.size) { recomputeBounds(width: geo.size.width, height: geo.size.height) }
        .onAppear { recomputeBounds(width: geo.size.width, height: geo.size.height) }
    }
    .coordinateSpace(name: "captionCanvas")
    .allowsHitTesting(onDrag != nil)
  }

  private func recomputeBounds(width: CGFloat, height: CGFloat) {
    let scaledFontSize = CaptionLayout.scaledFontSize(
      fontSize: fontSize,
      canvasWidth: width,
      canvasHeight: height,
      screenWidth: screenWidth
    )
    let maxTextWidth = width * CaptionLayout.maxWidthRatio
    let measured = CaptionLayout.measureText(
      text,
      scaledFontSize: scaledFontSize,
      fontWeight: fontWeight,
      maxTextWidth: maxTextWidth
    )
    let halfRelW = (measured.width / 2) / max(width, 1)
    let halfRelH = (measured.height / 2) / max(height, 1)
    cachedBounds = CaptionBounds(
      minX: halfRelW,
      maxX: 1.0 - halfRelW,
      minY: halfRelH,
      maxY: 1.0 - halfRelH
    )
  }
}

private struct CaptionBounds {
  var minX: CGFloat
  var maxX: CGFloat
  var minY: CGFloat
  var maxY: CGFloat

  static let `default` = CaptionBounds(minX: 0.05, maxX: 0.95, minY: 0.05, maxY: 0.95)
}
