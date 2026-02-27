import AppKit
import Foundation

extension EditorState {
  func setBackgroundImage(from sourceURL: URL) {
    guard let bundleURL = project?.bundleURL else { return }
    let fm = FileManager.default
    let contents = (try? fm.contentsOfDirectory(atPath: bundleURL.path)) ?? []
    for file in contents where file.hasPrefix("background-image.") {
      try? fm.removeItem(at: bundleURL.appendingPathComponent(file))
    }
    let filename = "background-image.\(sourceURL.pathExtension.lowercased())"
    let destURL = bundleURL.appendingPathComponent(filename)
    do {
      try fm.copyItem(at: sourceURL, to: destURL)
    } catch {
      logger.error("Failed to copy background image: \(error)")
      return
    }
    backgroundImage = NSImage(contentsOf: destURL)
    backgroundStyle = .image(filename)
  }

  func removeBackgroundImage() {
    if case .image(let filename) = backgroundStyle, let bundleURL = project?.bundleURL {
      let fileURL = bundleURL.appendingPathComponent(filename)
      try? FileManager.default.removeItem(at: fileURL)
    }
    backgroundImage = nil
    backgroundStyle = .solidColor(CodableColor(r: 0, g: 0, b: 0))
  }

  func backgroundImageURL() -> URL? {
    guard case .image(let filename) = backgroundStyle, let bundleURL = project?.bundleURL else {
      return nil
    }
    return bundleURL.appendingPathComponent(filename)
  }

  func setCameraBackgroundImage(from sourceURL: URL) {
    guard let bundleURL = project?.bundleURL else { return }
    let fm = FileManager.default
    let contents = (try? fm.contentsOfDirectory(atPath: bundleURL.path)) ?? []
    for file in contents where file.hasPrefix("camera-bg-image.") {
      try? fm.removeItem(at: bundleURL.appendingPathComponent(file))
    }
    let filename = "camera-bg-image.\(sourceURL.pathExtension.lowercased())"
    let destURL = bundleURL.appendingPathComponent(filename)
    do {
      try fm.copyItem(at: sourceURL, to: destURL)
    } catch {
      logger.error("Failed to copy camera background image: \(error)")
      return
    }
    cameraBackgroundImage = NSImage(contentsOf: destURL)
    cameraBackgroundStyle = .image(filename)
  }

  func removeCameraBackgroundImage() {
    if case .image(let filename) = cameraBackgroundStyle, let bundleURL = project?.bundleURL {
      let fileURL = bundleURL.appendingPathComponent(filename)
      try? FileManager.default.removeItem(at: fileURL)
    }
    cameraBackgroundImage = nil
    cameraBackgroundStyle = .none
  }

  func cameraBackgroundImageURL() -> URL? {
    guard case .image(let filename) = cameraBackgroundStyle, let bundleURL = project?.bundleURL else {
      return nil
    }
    return bundleURL.appendingPathComponent(filename)
  }
}
