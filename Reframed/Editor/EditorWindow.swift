import AppKit
import SwiftUI

@MainActor
final class EditorWindow: NSObject, NSWindowDelegate {
  private var window: NSWindow?
  private var editorState: EditorState?
  private var keyboardMonitor: Any?
  var onSave: ((URL) -> Void)?
  var onCancel: (() -> Void)?
  var onDelete: (() -> Void)?

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
      onSave: { [weak self] url in
        self?.editorState?.teardown()
        self?.window?.close()
        self?.onSave?(url)
      },
      onCancel: { [weak self] in
        self?.editorState?.teardown()
        self?.window?.close()
        self?.onCancel?()
      },
      onDelete: { [weak self] in
        self?.editorState?.teardown()
        self?.window?.close()
        self?.onDelete?()
      }
    )

    let hostingView = NSHostingView(rootView: editorView)

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1400, height: 900),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )

    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.styleMask.insert(.fullSizeContentView)
    window.backgroundColor = ReframedColors.panelBackgroundNS
    window.contentView = hostingView
    window.contentMinSize = NSSize(width: 1200, height: 800)
    window.minSize = NSSize(width: 1200, height: 800)
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
  }

  private func setupKeyboardMonitor() {
    removeKeyboardMonitor()
    keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self, let window = self.window, event.window == window else { return event }
      guard let state = self.editorState else { return event }

      if window.firstResponder is NSTextView {
        return event
      }

      let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
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

  func bringToFront() {
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func close() {
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

  func windowWillClose(_ notification: Notification) {
    removeKeyboardMonitor()
    editorState?.teardown()
    editorState = nil
    window = nil
    onCancel?()
  }
}
