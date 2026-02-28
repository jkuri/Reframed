import AppKit
import Foundation

extension EditorState {
  func deleteRecording() {
    pendingSaveTask?.cancel()
    pendingSaveTask = nil
    if let project {
      self.project = nil
      try? project.delete()
    } else {
      let fm = FileManager.default
      try? fm.removeItem(at: result.screenVideoURL)
      if let webcamURL = result.webcamVideoURL {
        try? fm.removeItem(at: webcamURL)
      }
      if let sysURL = result.systemAudioURL {
        try? fm.removeItem(at: sysURL)
      }
      if let micURL = result.microphoneAudioURL {
        try? fm.removeItem(at: micURL)
      }
    }
  }

  func openProjectFolder() {
    if let bundleURL = project?.bundleURL {
      NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
    } else {
      let dir = FileManager.default.projectSaveDirectory()
      NSWorkspace.shared.open(dir)
    }
  }

  func openExportedFile() {
    if let lastExportedURL {
      NSWorkspace.shared.activateFileViewerSelecting([lastExportedURL])
    } else {
      let dir = FileManager.default.defaultSaveDirectory()
      NSWorkspace.shared.open(dir)
    }
  }

  func renameProject(_ newName: String) {
    guard var proj = project else { return }
    do {
      try proj.rename(to: newName)
    } catch {
      logger.error("Failed to rename project: \(error)")
      return
    }
    project = proj
    result = proj.recordingResult
    projectName = proj.name
  }

  func saveState() {
    guard let project else { return }
    do {
      try project.saveEditorState(createSnapshot())
    } catch {
      logger.error("Failed to save editor state: \(error)")
    }
  }
}
