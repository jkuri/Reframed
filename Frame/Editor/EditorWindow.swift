import AppKit
import SwiftUI

@MainActor
final class EditorWindow: NSObject, NSWindowDelegate {
  private var window: NSWindow?
  private var editorState: EditorState?
  var onSave: ((URL) -> Void)?
  var onCancel: (() -> Void)?
  var onDelete: (() -> Void)?

  func show(project: FrameProject) {
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
      contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )

    window.titlebarAppearsTransparent = true
    window.backgroundColor = FrameColors.panelBackgroundNS
    window.contentView = hostingView
    window.minSize = NSSize(width: 900, height: 550)
    window.center()
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.title = "Frame Editor"
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    self.window = window
  }

  func bringToFront() {
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func close() {
    editorState?.teardown()
    window?.delegate = nil
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
