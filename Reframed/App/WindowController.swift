import AppKit
import ApplicationServices
import Combine
import ScreenCaptureKit

struct WindowInfo: Identifiable, Equatable {
  let id: Int
  let frame: CGRect
  let title: String
  let appPID: pid_t
  let appName: String
  let axElement: AXUIElement

  static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
    return lhs.id == rhs.id && lhs.frame == rhs.frame
  }
}

@MainActor
final class WindowController: ObservableObject {
  @Published var currentWindow: WindowInfo?

  private(set) var scWindows: [SCWindow] = []

  func updateSCWindows() async {
    do {
      let content = try await Permissions.fetchShareableContent()
      self.scWindows = content.windows
    } catch {
      print("Failed to fetch SCWindows: \(error)")
    }
  }

  func findWindow(at point: CGPoint) -> WindowInfo? {
    let myPID = ProcessInfo.processInfo.processIdentifier

    guard
      let windowList = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
      ) as? [[String: Any]]
    else {
      return nil
    }

    for windowDict in windowList {
      guard let pid = windowDict[kCGWindowOwnerPID as String] as? pid_t,
        pid != myPID,
        let layer = windowDict[kCGWindowLayer as String] as? Int,
        layer == 0,
        let boundsDict = windowDict[kCGWindowBounds as String],
        let bounds = CGRect(dictionaryRepresentation: boundsDict as! CFDictionary),
        bounds.width > 20,
        bounds.height > 20,
        bounds.contains(point)
      else { continue }

      let windowNumber = windowDict[kCGWindowNumber as String] as? Int ?? 0
      let title = windowDict[kCGWindowName as String] as? String ?? ""
      let app = NSRunningApplication(processIdentifier: pid)
      let appName = app?.localizedName ?? "Unknown"

      let axApp = AXUIElementCreateApplication(pid)
      let axWindow = findAXWindow(for: axApp, matching: bounds) ?? axApp

      let matchedID: Int
      if let match = scWindows.first(where: { $0.windowID == CGWindowID(windowNumber) }) {
        matchedID = Int(match.windowID)
      } else {
        matchedID = windowNumber
      }

      return WindowInfo(
        id: matchedID,
        frame: bounds,
        title: title,
        appPID: pid,
        appName: appName,
        axElement: axWindow
      )
    }

    return nil
  }

  private func findAXWindow(for app: AXUIElement, matching frame: CGRect) -> AXUIElement? {
    var windowsRef: CFTypeRef?
    AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef)
    guard let windows = windowsRef as? [AXUIElement] else { return nil }

    for window in windows {
      var positionRef: CFTypeRef?
      var sizeRef: CFTypeRef?
      AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef)
      AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)

      var pos = CGPoint.zero
      var size = CGSize.zero
      if let posRef = positionRef, CFGetTypeID(posRef) == AXValueGetTypeID() {
        AXValueGetValue(posRef as! AXValue, .cgPoint, &pos)
      }
      if let sRef = sizeRef, CFGetTypeID(sRef) == AXValueGetTypeID() {
        AXValueGetValue(sRef as! AXValue, .cgSize, &size)
      }

      if abs(pos.x - frame.origin.x) < 20 && abs(pos.y - frame.origin.y) < 20 && abs(size.width - frame.width) < 20
        && abs(size.height - frame.height) < 20
      {
        return window
      }
    }

    return nil
  }

  func allVisibleWindows() -> [WindowInfo] {
    let myPID = ProcessInfo.processInfo.processIdentifier
    guard
      let windowList = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
      ) as? [[String: Any]]
    else { return [] }

    var results: [WindowInfo] = []
    for windowDict in windowList {
      guard let pid = windowDict[kCGWindowOwnerPID as String] as? pid_t,
        pid != myPID,
        let layer = windowDict[kCGWindowLayer as String] as? Int,
        layer == 0,
        let boundsDict = windowDict[kCGWindowBounds as String],
        let bounds = CGRect(dictionaryRepresentation: boundsDict as! CFDictionary),
        bounds.width > 20,
        bounds.height > 20
      else { continue }

      let windowNumber = windowDict[kCGWindowNumber as String] as? Int ?? 0
      let title = windowDict[kCGWindowName as String] as? String ?? ""
      let app = NSRunningApplication(processIdentifier: pid)
      let appName = app?.localizedName ?? "Unknown"

      let axApp = AXUIElementCreateApplication(pid)
      let axWindow = findAXWindow(for: axApp, matching: bounds) ?? axApp

      let matchedID: Int
      if let match = scWindows.first(where: { $0.windowID == CGWindowID(windowNumber) }) {
        matchedID = Int(match.windowID)
      } else {
        matchedID = windowNumber
      }

      results.append(
        WindowInfo(
          id: matchedID,
          frame: bounds,
          title: title,
          appPID: pid,
          appName: appName,
          axElement: axWindow
        )
      )
    }
    return results
  }

  func cycleToNextWindow() {
    let windows = allVisibleWindows()
    guard !windows.isEmpty else { return }
    if let current = currentWindow, let idx = windows.firstIndex(where: { $0.id == current.id }) {
      let next = (idx + 1) % windows.count
      currentWindow = windows[next]
    } else {
      currentWindow = windows.first
    }
  }

  func cycleToPreviousWindow() {
    let windows = allVisibleWindows()
    guard !windows.isEmpty else { return }
    if let current = currentWindow, let idx = windows.firstIndex(where: { $0.id == current.id }) {
      let prev = (idx - 1 + windows.count) % windows.count
      currentWindow = windows[prev]
    } else {
      currentWindow = windows.last
    }
  }

  func resize(_ window: WindowInfo, to newSize: CGSize) {
    var size = newSize
    guard let sizeVal = AXValueCreate(.cgSize, &size) else { return }
    AXUIElementSetAttributeValue(window.axElement, kAXSizeAttribute as CFString, sizeVal)
    scheduleRefresh()
  }

  func center(_ window: WindowInfo) {
    guard let screen = NSScreen.main else { return }
    let screenFrame = screen.frame

    let targetX = screenFrame.width / 2 - window.frame.width / 2
    let targetY = screenFrame.height / 2 - window.frame.height / 2

    var point = CGPoint(x: screenFrame.origin.x + targetX, y: screenFrame.origin.y + targetY)
    guard let pointVal = AXValueCreate(.cgPoint, &point) else { return }
    AXUIElementSetAttributeValue(window.axElement, kAXPositionAttribute as CFString, pointVal)
    scheduleRefresh()
  }

  private func scheduleRefresh() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
      self?.rereadCurrentWindow()
    }
  }

  private func rereadCurrentWindow() {
    guard let current = currentWindow else { return }

    var positionRef: CFTypeRef?
    var sizeRef: CFTypeRef?
    AXUIElementCopyAttributeValue(current.axElement, kAXPositionAttribute as CFString, &positionRef)
    AXUIElementCopyAttributeValue(current.axElement, kAXSizeAttribute as CFString, &sizeRef)

    var pos = CGPoint.zero
    var size = CGSize.zero
    if let posRef = positionRef, CFGetTypeID(posRef) == AXValueGetTypeID() {
      AXValueGetValue(posRef as! AXValue, .cgPoint, &pos)
    }
    if let sRef = sizeRef, CFGetTypeID(sRef) == AXValueGetTypeID() {
      AXValueGetValue(sRef as! AXValue, .cgSize, &size)
    }

    let newFrame = CGRect(origin: pos, size: size)
    guard newFrame != current.frame else { return }

    currentWindow = WindowInfo(
      id: current.id,
      frame: newFrame,
      title: current.title,
      appPID: current.appPID,
      appName: current.appName,
      axElement: current.axElement
    )
  }
}
