import Foundation

struct HistoryData: Codable, Sendable {
  var snapshots: [EditorStateData]
  var currentIndex: Int
}

@MainActor
@Observable
final class History {
  private(set) var snapshots: [EditorStateData] = []
  private(set) var currentIndex: Int = -1

  private let maxSnapshots = 50

  var canUndo: Bool { currentIndex > 0 }
  var canRedo: Bool { currentIndex < snapshots.count - 1 }

  func pushSnapshot(_ snapshot: EditorStateData) {
    if currentIndex < snapshots.count - 1 {
      snapshots.removeSubrange((currentIndex + 1)...)
    }
    snapshots.append(snapshot)
    currentIndex = snapshots.count - 1
    if snapshots.count > maxSnapshots {
      let excess = snapshots.count - maxSnapshots
      snapshots.removeFirst(excess)
      currentIndex -= excess
    }
  }

  func undo() -> EditorStateData? {
    guard canUndo else { return nil }
    currentIndex -= 1
    return snapshots[currentIndex]
  }

  func redo() -> EditorStateData? {
    guard canRedo else { return nil }
    currentIndex += 1
    return snapshots[currentIndex]
  }

  func load(from data: HistoryData) {
    snapshots = data.snapshots
    currentIndex = min(data.currentIndex, snapshots.count - 1)
    if snapshots.count > maxSnapshots {
      let excess = snapshots.count - maxSnapshots
      snapshots.removeFirst(excess)
      currentIndex -= excess
    }
    if currentIndex < 0 && !snapshots.isEmpty {
      currentIndex = 0
    }
  }

  func toData() -> HistoryData {
    HistoryData(snapshots: snapshots, currentIndex: currentIndex)
  }
}
