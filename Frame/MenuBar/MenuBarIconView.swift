import SwiftUI

struct MenuBarIconView: View {
  let state: CaptureState

  var body: some View {
    switch state {
    case .idle:
      Image(systemName: "rectangle.dashed.badge.record")
    case .selecting:
      Image(systemName: "rectangle.dashed")
    case .recording:
      Image(systemName: "record.circle.fill")
        .symbolRenderingMode(.multicolor)
    case .paused:
      Image(systemName: "pause.circle.fill")
    case .processing:
      Image(systemName: "gear")
    case .editing:
      Image(systemName: "film")
    }
  }
}
