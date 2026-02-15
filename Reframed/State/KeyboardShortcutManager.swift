import AppKit

@MainActor
final class KeyboardShortcutManager {
  private weak var session: SessionState?
  private var globalMonitor: Any?
  private var localMonitor: Any?

  init(session: SessionState) {
    self.session = session
  }

  func start() {
    guard globalMonitor == nil else { return }

    globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
      MainActor.assumeIsolated {
        guard let self, let session = self.session else { return }
        for action in ShortcutAction.allCases where action.isGlobal {
          let shortcut = ConfigService.shared.shortcut(for: action)
          if shortcut.matches(event) {
            self.performAction(action, on: session)
            return
          }
        }
      }
    }

    localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self, let session = self.session else { return event }

      if let responder = event.window?.firstResponder, responder is NSTextView {
        return event
      }

      for action in ShortcutAction.allCases {
        let shortcut = ConfigService.shared.shortcut(for: action)
        if shortcut.matches(event) {
          self.performAction(action, on: session)
          return nil
        }
      }
      return event
    }
  }

  func stop() {
    if let globalMonitor {
      NSEvent.removeMonitor(globalMonitor)
    }
    globalMonitor = nil

    if let localMonitor {
      NSEvent.removeMonitor(localMonitor)
    }
    localMonitor = nil
  }

  private func performAction(_ action: ShortcutAction, on session: SessionState) {
    switch action {
    case .switchToDisplay:
      guard case .idle = session.state else { return }
      session.selectMode(.entireScreen)

    case .switchToWindow:
      guard case .idle = session.state else { return }
      session.selectMode(.selectedWindow)

    case .switchToArea:
      guard case .idle = session.state else { return }
      session.selectMode(.selectedArea)

    case .stopRecording:
      switch session.state {
      case .recording, .paused:
        Task {
          try? await session.stopRecording()
        }
      default:
        break
      }

    case .pauseResumeRecording:
      switch session.state {
      case .recording:
        session.pauseRecording()
      case .paused:
        session.resumeRecording()
      default:
        break
      }

    case .restartRecording:
      switch session.state {
      case .recording, .paused, .countdown:
        session.restartRecording()
      default:
        break
      }
    }
  }
}
