import AppKit
import Foundation

struct KeyboardShortcut: Codable, Equatable, Sendable {
  var keyCode: UInt16
  var modifierFlags: UInt

  func matches(_ event: NSEvent) -> Bool {
    let mask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
    let eventMods = event.modifierFlags.intersection(mask).rawValue
    return event.keyCode == keyCode && eventMods == modifierFlags
  }

  func matchesCGEvent(keyCode: Int64, flags: CGEventFlags) -> Bool {
    let mask: UInt64 =
      CGEventFlags.maskCommand.rawValue
      | CGEventFlags.maskShift.rawValue
      | CGEventFlags.maskAlternate.rawValue
      | CGEventFlags.maskControl.rawValue
    let eventMods = flags.rawValue & mask
    return Int64(self.keyCode) == keyCode && eventMods == UInt64(modifierFlags)
  }

  var displayString: String {
    var parts: [String] = []
    let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
    if flags.contains(.control) { parts.append("\u{2303}") }
    if flags.contains(.option) { parts.append("\u{2325}") }
    if flags.contains(.shift) { parts.append("\u{21E7}") }
    if flags.contains(.command) { parts.append("\u{2318}") }
    parts.append(Self.keyName(for: keyCode))
    return parts.joined()
  }

  static func keyName(for keyCode: UInt16) -> String {
    switch keyCode {
    case 0: return "A"
    case 1: return "S"
    case 2: return "D"
    case 3: return "F"
    case 4: return "H"
    case 5: return "G"
    case 6: return "Z"
    case 7: return "X"
    case 8: return "C"
    case 9: return "V"
    case 11: return "B"
    case 12: return "Q"
    case 13: return "W"
    case 14: return "E"
    case 15: return "R"
    case 16: return "Y"
    case 17: return "T"
    case 18: return "1"
    case 19: return "2"
    case 20: return "3"
    case 21: return "4"
    case 22: return "6"
    case 23: return "5"
    case 24: return "="
    case 25: return "9"
    case 26: return "7"
    case 27: return "-"
    case 28: return "8"
    case 29: return "0"
    case 30: return "]"
    case 31: return "O"
    case 32: return "U"
    case 33: return "["
    case 34: return "I"
    case 35: return "P"
    case 36: return "\u{21A9}"
    case 37: return "L"
    case 38: return "J"
    case 39: return "'"
    case 40: return "K"
    case 41: return ";"
    case 42: return "\\"
    case 43: return ","
    case 44: return "/"
    case 45: return "N"
    case 46: return "M"
    case 47: return "."
    case 48: return "\u{21E5}"
    case 49: return "\u{2423}"
    case 50: return "`"
    case 51: return "\u{232B}"
    case 53: return "\u{238B}"
    case 96: return "F5"
    case 97: return "F6"
    case 98: return "F7"
    case 99: return "F3"
    case 100: return "F8"
    case 101: return "F9"
    case 103: return "F11"
    case 105: return "F13"
    case 107: return "F14"
    case 109: return "F10"
    case 111: return "F12"
    case 113: return "F15"
    case 118: return "F4"
    case 120: return "F2"
    case 122: return "F1"
    case 123: return "\u{2190}"
    case 124: return "\u{2192}"
    case 125: return "\u{2193}"
    case 126: return "\u{2191}"
    default: return "Key\(keyCode)"
    }
  }
}

enum ShortcutAction: String, CaseIterable, Codable, Sendable {
  case switchToDisplay
  case switchToWindow
  case switchToArea
  case stopRecording
  case pauseResumeRecording
  case restartRecording
  case editorUndo
  case editorRedo

  var label: String {
    switch self {
    case .switchToDisplay: return "Display Mode"
    case .switchToWindow: return "Window Mode"
    case .switchToArea: return "Area Mode"
    case .stopRecording: return "Stop Recording"
    case .pauseResumeRecording: return "Pause / Resume"
    case .restartRecording: return "Restart Recording"
    case .editorUndo: return "Undo"
    case .editorRedo: return "Redo"
    }
  }

  var isGlobal: Bool {
    switch self {
    case .switchToDisplay, .switchToWindow, .switchToArea:
      return false
    case .stopRecording, .pauseResumeRecording, .restartRecording:
      return true
    case .editorUndo, .editorRedo:
      return false
    }
  }

  var defaultShortcut: KeyboardShortcut {
    let cmd = NSEvent.ModifierFlags.command.rawValue
    let shift = NSEvent.ModifierFlags.shift.rawValue
    let cmdShift = cmd | shift

    switch self {
    case .switchToDisplay:
      return KeyboardShortcut(keyCode: 2, modifierFlags: cmdShift)
    case .switchToWindow:
      return KeyboardShortcut(keyCode: 13, modifierFlags: cmdShift)
    case .switchToArea:
      return KeyboardShortcut(keyCode: 0, modifierFlags: cmdShift)
    case .stopRecording:
      return KeyboardShortcut(keyCode: 1, modifierFlags: cmdShift)
    case .pauseResumeRecording:
      return KeyboardShortcut(keyCode: 35, modifierFlags: cmdShift)
    case .restartRecording:
      return KeyboardShortcut(keyCode: 15, modifierFlags: cmdShift)
    case .editorUndo:
      return KeyboardShortcut(keyCode: 6, modifierFlags: cmd)
    case .editorRedo:
      return KeyboardShortcut(keyCode: 6, modifierFlags: cmdShift)
    }
  }
}

extension Notification.Name {
  static let shortcutsDidChange = Notification.Name("shortcutsDidChange")
}
