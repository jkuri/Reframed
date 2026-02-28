import SwiftUI

struct CaptureAreaView: View {
  let session: SessionState
  @State private var x: Int = 0
  @State private var y: Int = 0
  @State private var w: Int = 0
  @State private var h: Int = 0
  @State private var isEditing = false

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 10) {
        HStack(spacing: 0) {
          Text("Size")
            .font(.system(size: 12))
            .foregroundStyle(ReframedColors.secondaryText)
            .frame(width: 56, alignment: .leading)

          NumberField(value: $w, onCommit: commitEditing)
            .onTapGesture { isEditing = true }
            .onChange(of: w) { if isEditing { applyValues() } }
          Text("\u{00D7}")
            .font(.system(size: 12))
            .foregroundStyle(ReframedColors.secondaryText)
            .frame(width: 20)
          NumberField(value: $h, onCommit: commitEditing)
            .onTapGesture { isEditing = true }
            .onChange(of: h) { if isEditing { applyValues() } }
          Text("px")
            .font(.system(size: 11))
            .foregroundStyle(ReframedColors.secondaryText)
            .frame(width: 24, alignment: .trailing)
        }

        HStack(spacing: 0) {
          Text("Position")
            .font(.system(size: 12))
            .foregroundStyle(ReframedColors.secondaryText)
            .frame(width: 56, alignment: .leading)

          NumberField(value: $x, onCommit: commitEditing)
            .onTapGesture { isEditing = true }
            .onChange(of: x) { if isEditing { applyValues() } }
          Spacer().frame(width: 20)
          NumberField(value: $y, onCommit: commitEditing)
            .onTapGesture { isEditing = true }
            .onChange(of: y) { if isEditing { applyValues() } }
          Text("px")
            .font(.system(size: 11))
            .foregroundStyle(ReframedColors.secondaryText)
            .frame(width: 24, alignment: .trailing)
        }
      }
      .padding(.horizontal, 30)
      .padding(.vertical, 30)
      .background(ReframedColors.background)
      .clipShape(RoundedRectangle(cornerRadius: Radius.md))

      StartRecordingButton(
        delay: session.options.timerDelay.rawValue,
        onCountdownStart: { session.hideToolbar() },
        onCancel: { session.cancelSelection() },
        action: { session.overlayView?.confirmSelection() }
      )
      .padding(.top, 8)
    }
    .frame(width: 260)
    .onReceive(NotificationCenter.default.publisher(for: .selectionRectChanged)) { notification in
      guard !isEditing, let rect = notification.object as? NSValue else { return }
      let r = rect.rectValue
      x = Int(r.origin.x)
      y = Int(r.origin.y)
      w = Int(r.width)
      h = Int(r.height)
    }
  }

  private func commitEditing() {
    isEditing = false
    applyValues()
  }

  private func applyValues() {
    let rect = CGRect(
      x: CGFloat(x),
      y: CGFloat(y),
      width: CGFloat(max(w, 10)),
      height: CGFloat(max(h, 10))
    )
    session.updateOverlaySelection(rect)
  }
}

extension Notification.Name {
  static let selectionRectChanged = Notification.Name("selectionRectChanged")
}
