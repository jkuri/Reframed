import SwiftUI

struct CaptureAreaView: View {
  let session: SessionState
  @State private var x: Int = 0
  @State private var y: Int = 0
  @State private var w: Int = 0
  @State private var h: Int = 0
  @State private var isEditing = false
  @State private var showPresets = false
  @State private var triggerStart = false

  private let textColor = Color.black
  private let secondaryTextColor = Color.black.opacity(0.6)
  private let fieldBg = Color.black.opacity(0.04)
  private let fieldBorder = Color.black.opacity(0.1)

  private let presets: [(String, Int, Int)] = [
    ("1920 \u{00d7} 1080", 1920, 1080),
    ("1280 \u{00d7} 720", 1280, 720),
    ("2560 \u{00d7} 1440", 2560, 1440),
    ("1080 \u{00d7} 1080", 1080, 1080),
    ("1080 \u{00d7} 1920", 1080, 1920),
  ]

  var body: some View {
    VStack(spacing: 16) {
      HStack(spacing: 12) {
        fieldGroup("Size") {
          HStack(spacing: 6) {
            lightNumberField(value: $w)
              .onTapGesture { isEditing = true }
              .onChange(of: w) { if isEditing { applyValues() } }
            Text("\u{00D7}")
              .font(.system(size: FontSize.xxs))
              .foregroundStyle(secondaryTextColor)
            lightNumberField(value: $h)
              .onTapGesture { isEditing = true }
              .onChange(of: h) { if isEditing { applyValues() } }
          }
        }

        fieldGroup("Position") {
          HStack(spacing: 6) {
            lightNumberField(value: $x)
              .onTapGesture { isEditing = true }
              .onChange(of: x) { if isEditing { applyValues() } }
            Text("\u{00D7}")
              .font(.system(size: FontSize.xxs))
              .foregroundStyle(secondaryTextColor)
              .hidden()
            lightNumberField(value: $y)
              .onTapGesture { isEditing = true }
              .onChange(of: y) { if isEditing { applyValues() } }
          }
        }
      }

      HStack(spacing: 6) {
        Button("Presets") { showPresets.toggle() }
          .buttonStyle(SecondaryButtonStyle(size: .small, forceLightMode: true))
          .popover(isPresented: $showPresets, arrowEdge: .bottom) {
            AreaSizePresetsPopover(presets: presets) { pw, ph in
              w = pw
              h = ph
              showPresets = false
              applyValues()
            }
          }

        Button("Center") {
          centerSelection()
        }
        .buttonStyle(SecondaryButtonStyle(size: .small, forceLightMode: true))
      }

      StartRecordingButton(
        delay: session.options.timerDelay.rawValue,
        onCountdownStart: { session.hideToolbar() },
        onCancel: { session.cancelSelection() },
        action: { session.overlayView?.confirmSelection() },
        trigger: $triggerStart
      )

      Text("Shift to lock aspect ratio \u{00b7} Esc to cancel \u{00b7} Enter to start")
        .font(.system(size: FontSize.xxs))
        .foregroundStyle(Color.black.opacity(0.35))
    }
    .padding(24)
    .background(ReframedColors.overlayCardBackground)
    .clipShape(RoundedRectangle(cornerRadius: Radius.xxl))
    .shadow(radius: 20)
    .onReceive(NotificationCenter.default.publisher(for: .selectionRectChanged)) { notification in
      guard !isEditing, let rect = notification.object as? NSValue else { return }
      let r = rect.rectValue
      x = Int(r.origin.x)
      y = Int(r.origin.y)
      w = Int(r.width)
      h = Int(r.height)
    }
    .onReceive(NotificationCenter.default.publisher(for: .areaSelectionConfirmRequested)) { _ in
      triggerStart = true
    }
  }

  private func fieldGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 6) {
      Text(title)
        .font(.system(size: FontSize.xxs, weight: .medium))
        .foregroundStyle(secondaryTextColor)
      content()
    }
  }

  private func lightNumberField(value: Binding<Int>) -> some View {
    TextField("", value: value, format: .number)
      .textFieldStyle(.plain)
      .font(.system(size: FontSize.xs, design: .monospaced))
      .foregroundStyle(textColor)
      .multilineTextAlignment(.center)
      .frame(width: 70, height: 40)
      .background(fieldBg)
      .clipShape(RoundedRectangle(cornerRadius: Radius.md))
      .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(fieldBorder))
      .onSubmit { commitEditing() }
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

  private func centerSelection() {
    guard let screen = NSScreen.main else { return }
    let screenFrame = screen.frame
    x = Int((screenFrame.width - CGFloat(w)) / 2)
    y = Int((screenFrame.height - CGFloat(h)) / 2)
    applyValues()
  }
}

extension Notification.Name {
  static let selectionRectChanged = Notification.Name("selectionRectChanged")
  static let areaSelectionConfirmRequested = Notification.Name("areaSelectionConfirmRequested")
}
