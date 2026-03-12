import AppKit
import Foundation

@MainActor
extension SessionState {
  func projectSourceName() -> String? {
    switch captureTarget {
    case .window(let window):
      return window.owningApplication?.applicationName
    case .region(let selection):
      if captureMode == .entireScreen {
        return NSScreen.screen(for: selection.displayID)?.localizedName
      }
      return nil
    case .none:
      if captureMode == .device {
        return deviceName
      }
      return nil
    }
  }

  func openEditor(project: ReframedProject?, result: RecordingResult? = nil) {
    hideToolbar()
    transition(to: .editing)

    let editor = EditorWindow()
    editor.onSave = { [weak self, weak editor] url in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.lastRecordingURL = url
        self.logger.info("Editor save: \(url.path)")
        if let editor { self.removeEditor(editor) }
      }
    }
    editor.onCancel = { [weak self, weak editor] in
      MainActor.assumeIsolated {
        if let self, let editor { self.removeEditor(editor) }
      }
    }
    editor.onDelete = { [weak self, weak editor] in
      MainActor.assumeIsolated {
        if let self, let editor { self.removeEditor(editor) }
      }
    }
    editor.onExportingChanged = { [weak self] exporting in
      MainActor.assumeIsolated {
        self?.updateStatusIcon()
      }
    }
    if let project {
      editor.show(project: project)
    } else if let result {
      editor.show(result: result)
    }
    editorWindows.append(editor)
  }

  func openProject(at url: URL) {
    do {
      let project = try ReframedProject.open(at: url)
      openEditor(project: project)
    } catch {
      logger.error("Failed to open project: \(error)")
      showError("Failed to open project: \(error.localizedDescription)")
    }
  }

  func removeEditor(_ editor: EditorWindow) {
    editorWindows.removeAll { $0 === editor }
    if editorWindows.isEmpty {
      captureMode = .none
      transition(to: .idle)
    }
  }
}
