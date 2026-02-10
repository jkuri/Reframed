import AppKit
import SwiftUI

@MainActor
final class EditorWindow: NSObject, NSWindowDelegate {
  private var window: NSWindow?
  private var editorState: EditorState?
  var onSave: ((URL) -> Void)?
  var onCancel: (() -> Void)?

  func show(result: RecordingResult) {
    let state = EditorState(result: result)
    self.editorState = state

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
      }
    )

    let hostingView = NSHostingView(rootView: editorView)

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 900, height: 640),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )

    window.titlebarAppearsTransparent = true
    window.backgroundColor = FrameColors.panelBackgroundNS
    window.contentView = hostingView
    window.minSize = NSSize(width: 700, height: 500)
    window.center()
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.title = "Frame Editor"
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    self.window = window
  }

  func close() {
    editorState?.teardown()
    window?.close()
    window = nil
    editorState = nil
  }

  func windowWillClose(_ notification: Notification) {
    editorState?.teardown()
    editorState = nil
    window = nil
    onCancel?()
  }
}
