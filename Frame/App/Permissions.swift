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

  static func fetchShareableContent() async throws -> SCShareableContent {
    try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
  }
}
