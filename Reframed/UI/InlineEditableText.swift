import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class InlineEditModel {
  var isEditing = false
  var editText = ""
  @ObservationIgnored var text = ""
  @ObservationIgnored var onCommit: ((String) -> Void)?
  @ObservationIgnored var resignFocus: (() -> Void)?
  @ObservationIgnored var fieldFrame: CGRect = .zero
  @ObservationIgnored var fieldWindow: NSWindow?
  @ObservationIgnored private var monitor: Any?

  func begin(text: String, onCommit: @escaping (String) -> Void, resignFocus: @escaping () -> Void) {
    self.text = text
    self.onCommit = onCommit
    self.resignFocus = resignFocus
    editText = text
    isEditing = true
    startMonitor()
  }

  func commit() {
    guard isEditing else { return }
    let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty, trimmed != text {
      onCommit?(trimmed)
    }
    isEditing = false
    stopMonitor()
  }

  func cancel() {
    guard isEditing else { return }
    isEditing = false
    stopMonitor()
  }

  func updateGeometry(frame: CGRect, window: NSWindow?) {
    fieldFrame = frame
    fieldWindow = window
  }

  func handleMouseDown(at point: CGPoint, in window: NSWindow?) -> Bool {
    guard isEditing else { return false }
    guard !(window === fieldWindow && fieldFrame.contains(point)) else { return false }
    commit()
    resignFocus?()
    return true
  }

  private func startMonitor() {
    guard monitor == nil else { return }
    monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
      guard let self else { return event }
      _ = self.handleMouseDown(at: event.locationInWindow, in: event.window)
      return event
    }
  }

  func stopMonitor() {
    if let monitor { NSEvent.removeMonitor(monitor) }
    monitor = nil
  }
}

struct InlineEditableText: View {
  let text: String
  let onCommit: (String) -> Void

  @State private var model = InlineEditModel()
  @FocusState private var isFocused: Bool
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    if model.isEditing {
      TextField("", text: $model.editText)
        .font(.system(size: FontSize.xs))
        .foregroundStyle(ReframedColors.primaryText)
        .textFieldStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(FieldFrameReader(model: model).frame(maxWidth: .infinity, maxHeight: .infinity))
        .background(ReframedColors.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(ReframedColors.border))
        .focused($isFocused)
        .onSubmit { model.commit() }
        .onChange(of: isFocused) { _, focused in
          if !focused { model.commit() }
        }
        .onExitCommand { model.cancel() }
        .onAppear { isFocused = true }
        .onDisappear { model.stopMonitor() }
    } else {
      HStack(spacing: 4) {
        Text(text)
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.primaryText)
          .lineLimit(1)

        Spacer()

        Image(systemName: "pencil")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.secondaryText)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(ReframedColors.fieldBackground.opacity(0.5))
      .clipShape(RoundedRectangle(cornerRadius: Radius.md))
      .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(ReframedColors.border))
      .onTapGesture {
        model.begin(
          text: text,
          onCommit: onCommit,
          resignFocus: { isFocused = false }
        )
      }
    }
  }
}

private struct FieldFrameReader: NSViewRepresentable {
  weak var model: InlineEditModel?

  func makeNSView(context: Context) -> ReportingView {
    let view = ReportingView()
    view.model = model
    return view
  }

  func updateNSView(_ view: ReportingView, context: Context) {
    view.model = model
    view.report()
  }

  final class ReportingView: NSView {
    weak var model: InlineEditModel?

    override func hitTest(_ point: NSPoint) -> NSView? {
      nil
    }

    override func layout() {
      super.layout()
      report()
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      report()
    }

    func report() {
      MainActor.assumeIsolated {
        model?.updateGeometry(frame: convert(bounds, to: nil), window: window)
      }
    }
  }
}
