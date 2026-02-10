import ApplicationServices
import Foundation
import ScreenCaptureKit

enum Permissions {
  static var hasScreenRecordingPermission: Bool {
    CGPreflightScreenCaptureAccess()
  }

  @discardableResult
  static func requestScreenRecordingPermission() -> Bool {
    CGRequestScreenCaptureAccess()
  }

  static var hasAccessibilityPermission: Bool {
    AXIsProcessTrusted()
  }

  static func requestAccessibilityPermission() {
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    AXIsProcessTrustedWithOptions(options)
  }

  static var allPermissionsGranted: Bool {
    hasScreenRecordingPermission && hasAccessibilityPermission
  }

  static func fetchShareableContent() async throws -> SCShareableContent {
    try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
  }
}
