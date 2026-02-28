import AppKit
import SwiftUI

@MainActor
final class EditorWindow: NSObject, NSWindowDelegate {
  private var window: NSWindow?
  private var editorState: EditorState?
  private var keyboardMonitor: Any?
  private var exportObservation: Task<Void, Never>?
  var onSave: ((URL) -> Void)?
  var onCancel: (() -> Void)?
  var onDelete: (() -> Void)?
  var onExportingChanged: ((Bool) -> Void)?

  func show(project: ReframedProject) {
    let state = EditorState(project: project)
    self.editorState = state

    showWindow(state: state)
  }

  func show(result: RecordingResult) {
    let state = EditorState(result: result)
    self.editorState = state

    showWindow(state: state)
  }

  private func showWindow(state: EditorState) {

    let editorView = EditorView(
      editorState: state,
      onDelete: { [weak self] in
        self?.editorState?.teardown()
        self?.window?.close()
        self?.onDelete?()
      }
    )

    let hostingView = NSHostingView(rootView: editorView)

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: Layout.editorWindowMinWidth, height: Layout.editorWindowMinHeight),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )

    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.styleMask.insert(.fullSizeContentView)
    window.backgroundColor = ReframedColors.backgroundContainerNS
    window.contentView = hostingView
    window.contentMinSize = NSSize(width: Layout.editorWindowMinWidth, height: Layout.editorWindowMinHeight)
    window.minSize = NSSize(width: Layout.editorWindowMinWidth, height: Layout.editorWindowMinHeight)
    if let savedFrame = StateService.shared.editorWindowFrame {
      window.setFrame(savedFrame, display: true)
    } else {
      window.center()
    }
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.title = "Reframed Editor"
    window.level = .floating
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    DispatchQueue.main.async {
      window.level = .normal
    }

    self.window = window
    setupKeyboardMonitor()
    observeExporting(state: state)
  }

  private func observeExporting(state: EditorState) {
    exportObservation?.cancel()
    exportObservation = Task { [weak self] in
      var lastValue = state.isExporting
      while !Task.isCancelled {
        let current = state.isExporting
        if current != lastValue {
          lastValue = current
          self?.onExportingChanged?(current)
        }
        await withCheckedContinuation { continuation in
          withObservationTracking {
            _ = state.isExporting
          } onChange: {
            continuation.resume()
          }
        }
      }
    }
  }

  private func setupKeyboardMonitor() {
    removeKeyboardMonitor()
    keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self, let window = self.window, event.window == window else { return event }
      guard let state = self.editorState else { return event }

      if let textView = window.firstResponder as? NSTextView, textView.isFieldEditor {
        return event
      }

      let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

      let undoShortcut = ConfigService.shared.shortcut(for: .editorUndo)
      let redoShortcut = ConfigService.shared.shortcut(for: .editorRedo)
      if redoShortcut.matches(event) {
        state.redo()
        return nil
      }
      if undoShortcut.matches(event) {
        state.undo()
        return nil
      }

      if modifiers.contains(.command) || modifiers.contains(.option) || modifiers.contains(.control) {
        return event
      }

      switch event.keyCode {
      case 49, 36:
        state.togglePlayPause()
        return nil
      case 53:
        if state.isPreviewMode {
          state.isPreviewMode = false
          return nil
        }
        return event
      case 123:
        state.skipBackward()
        return nil
      case 124:
        state.skipForward()
        return nil
      default:
        return event
      }
    }
  }

  private func removeKeyboardMonitor() {
    if let monitor = keyboardMonitor {
      NSEvent.removeMonitor(monitor)
      keyboardMonitor = nil
    }
  }

  var isExporting: Bool {
    editorState?.isExporting ?? false
  }

  func bringToFront() {
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func close() {
    exportObservation?.cancel()
    removeKeyboardMonitor()
    editorState?.teardown()
    window?.delegate = nil
    window?.close()
    window = nil
    editorState = nil
  }

  func windowDidResize(_ notification: Notification) {
    guard let frame = window?.frame else { return }
    StateService.shared.editorWindowFrame = frame
  }

  func windowDidMove(_ notification: Notification) {
    guard let frame = window?.frame else { return }
    StateService.shared.editorWindowFrame = frame
  }

  func windowDidChangeEffectiveAppearance(_ notification: Notification) {
    window?.backgroundColor = ReframedColors.backgroundContainerNS
  }

  func windowWillClose(_ notification: Notification) {
    exportObservation?.cancel()
    removeKeyboardMonitor()
    editorState?.teardown()
    editorState = nil
    window = nil
    onCancel?()
  }
}
