import CoreGraphics
import Foundation

struct ZoomKeyframe: Codable, Sendable, Equatable {
  var t: Double
  var zoomLevel: Double
  var centerX: Double
  var centerY: Double
  var isAuto: Bool
}

final class ZoomTimeline: @unchecked Sendable {
  private let lock = NSLock()
  private var keyframes: [ZoomKeyframe] = []

  init(keyframes: [ZoomKeyframe] = []) {
    self.keyframes = keyframes.sorted { $0.t < $1.t }
  }

  var allKeyframes: [ZoomKeyframe] {
    lock.lock()
    let kfs = keyframes
    lock.unlock()
    return kfs
  }

  func zoomRect(at time: Double) -> CGRect {
    lock.lock()
    let kfs = keyframes
    lock.unlock()

    guard !kfs.isEmpty else {
      return CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    if time <= kfs.first!.t {
      return ztpRect(for: kfs.first!)
    }
    if time >= kfs.last!.t {
      return ztpRect(for: kfs.last!)
    }

    var lo = 0
    var hi = kfs.count - 1
    while lo < hi - 1 {
      let mid = (lo + hi) / 2
      if kfs[mid].t <= time {
        lo = mid
      } else {
        hi = mid
      }
    }

    let k0 = kfs[lo]
    let k1 = kfs[hi]
    let span = k1.t - k0.t
    guard span > 0 else {
      return ztpRect(for: k1)
    }

    let linearT = (time - k0.t) / span
    let t = easeInOut(linearT)

    let inv0 = 1.0 / k0.zoomLevel
    let inv1 = 1.0 / k1.zoomLevel
    let zoom = 1.0 / (inv0 + (inv1 - inv0) * t)

    if zoom <= 1.0 {
      return CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    let cx = k0.centerX + (k1.centerX - k0.centerX) * t
    let cy = k0.centerY + (k1.centerY - k0.centerY) * t
    let visibleW = 1.0 / zoom
    let visibleH = 1.0 / zoom
    let originX = cx * (1 - visibleW)
    let originY = cy * (1 - visibleH)

    return CGRect(x: originX, y: originY, width: visibleW, height: visibleH)
  }

  func addKeyframe(_ keyframe: ZoomKeyframe) {
    lock.lock()
    keyframes.append(keyframe)
    keyframes.sort { $0.t < $1.t }
    lock.unlock()
  }

  func removeKeyframe(at index: Int) {
    lock.lock()
    guard index >= 0 && index < keyframes.count else {
      lock.unlock()
      return
    }
    keyframes.remove(at: index)
    lock.unlock()
  }

  func setKeyframes(_ newKeyframes: [ZoomKeyframe]) {
    lock.lock()
    keyframes = newKeyframes.sorted { $0.t < $1.t }
    lock.unlock()
  }

  func clearAutoKeyframes() {
    lock.lock()
    keyframes.removeAll { $0.isAuto }
    lock.unlock()
  }

  var isEmpty: Bool {
    lock.lock()
    let empty = keyframes.isEmpty
    lock.unlock()
    return empty
  }

  private func ztpRect(for k: ZoomKeyframe) -> CGRect {
    if k.zoomLevel <= 1.0 {
      return CGRect(x: 0, y: 0, width: 1, height: 1)
    }
    let visibleW = 1.0 / k.zoomLevel
    let visibleH = 1.0 / k.zoomLevel
    let originX = k.centerX * (1 - visibleW)
    let originY = k.centerY * (1 - visibleH)
    return CGRect(x: originX, y: originY, width: visibleW, height: visibleH)
  }

  static func followCursor(_ rect: CGRect, cursorPosition: CGPoint) -> CGRect {
    guard rect.width < 1.0 || rect.height < 1.0 else { return rect }
    let cx = max(0, min(1, cursorPosition.x))
    let cy = max(0, min(1, cursorPosition.y))
    let originX = cx * (1 - rect.width)
    let originY = cy * (1 - rect.height)
    return CGRect(x: originX, y: originY, width: rect.width, height: rect.height)
  }

  private func easeInOut(_ t: Double) -> Double {
    t * t * t * (t * (t * 6 - 15) + 10)
  }
}
