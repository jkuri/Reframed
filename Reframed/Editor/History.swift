import Foundation

struct HistoryEntry: Codable, Sendable {
  var snapshot: EditorStateData
  var timestamp: Date
}

struct HistoryData: Codable, Sendable {
  var entries: [HistoryEntry]
  var currentIndex: Int
}

@MainActor
@Observable
final class History {
  private(set) var entries: [HistoryEntry] = []
  private(set) var currentIndex: Int = -1

  private let maxSnapshots = 50

  var canUndo: Bool { currentIndex > 0 }
  var canRedo: Bool { currentIndex < entries.count - 1 }

  func pushSnapshot(_ snapshot: EditorStateData) {
    if currentIndex < entries.count - 1 {
      entries.removeSubrange((currentIndex + 1)...)
    }
    entries.append(HistoryEntry(snapshot: snapshot, timestamp: Date()))
    currentIndex = entries.count - 1
    if entries.count > maxSnapshots {
      let excess = entries.count - maxSnapshots
      entries.removeFirst(excess)
      currentIndex -= excess
    }
  }

  func undo() -> EditorStateData? {
    guard canUndo else { return nil }
    currentIndex -= 1
    return entries[currentIndex].snapshot
  }

  func redo() -> EditorStateData? {
    guard canRedo else { return nil }
    currentIndex += 1
    return entries[currentIndex].snapshot
  }

  func jumpTo(index: Int) -> EditorStateData? {
    guard index >= 0 && index < entries.count else { return nil }
    currentIndex = index
    return entries[index].snapshot
  }

  func load(from data: HistoryData) {
    entries = data.entries
    currentIndex = min(data.currentIndex, entries.count - 1)
    if entries.count > maxSnapshots {
      let excess = entries.count - maxSnapshots
      entries.removeFirst(excess)
      currentIndex -= excess
    }
    if currentIndex < 0 && !entries.isEmpty {
      currentIndex = 0
    }
  }

  func toData() -> HistoryData {
    HistoryData(entries: entries, currentIndex: currentIndex)
  }

  typealias ChangeRule = (EditorStateData, EditorStateData) -> [String]

  static func prop<V: Equatable>(
    _ keyPath: KeyPath<EditorStateData, V>,
    _ describe: @escaping (V) -> String
  ) -> ChangeRule {
    { old, new in
      guard old[keyPath: keyPath] != new[keyPath: keyPath] else { return [] }
      return [describe(new[keyPath: keyPath])]
    }
  }

  static func toggle(
    _ keyPath: KeyPath<EditorStateData, Bool?>,
    default defaultValue: Bool,
    on: String,
    off: String
  ) -> ChangeRule {
    { old, new in
      guard old[keyPath: keyPath] != new[keyPath: keyPath] else { return [] }
      return [(new[keyPath: keyPath] ?? defaultValue) ? on : off]
    }
  }

  static func sub<S, V: Equatable>(
    _ parentPath: KeyPath<EditorStateData, S?>,
    _ childPath: KeyPath<S, V>,
    default defaultValue: V,
    _ describe: @escaping (V) -> String
  ) -> ChangeRule {
    { old, new in
      let oldVal: V
      let newVal: V
      if let parent = old[keyPath: parentPath] {
        oldVal = parent[keyPath: childPath]
      } else {
        oldVal = defaultValue
      }
      if let parent = new[keyPath: parentPath] {
        newVal = parent[keyPath: childPath]
      } else {
        newVal = defaultValue
      }
      guard oldVal != newVal else { return [] }
      return [describe(newVal)]
    }
  }

  static func subToggle<S>(
    _ parentPath: KeyPath<EditorStateData, S?>,
    _ childPath: KeyPath<S, Bool>,
    default defaultValue: Bool,
    on: String,
    off: String
  ) -> ChangeRule {
    { old, new in
      let oldVal: Bool
      let newVal: Bool
      if let parent = old[keyPath: parentPath] {
        oldVal = parent[keyPath: childPath]
      } else {
        oldVal = defaultValue
      }
      if let parent = new[keyPath: parentPath] {
        newVal = parent[keyPath: childPath]
      } else {
        newVal = defaultValue
      }
      guard oldVal != newVal else { return [] }
      return [newVal ? on : off]
    }
  }

  static func regions<R: Equatable>(
    _ keyPath: KeyPath<EditorStateData, [R]?>,
    added: String,
    removed: String,
    adjusted: String
  ) -> ChangeRule {
    { old, new in
      let o = old[keyPath: keyPath]
      let n = new[keyPath: keyPath]
      guard o != n else { return [] }
      let oldCount = o?.count ?? 0
      let newCount = n?.count ?? 0
      if newCount > oldCount { return [added] }
      if newCount < oldCount { return [removed] }
      return [adjusted]
    }
  }
}
