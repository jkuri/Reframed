import SwiftUI

struct ZoomRegion {
  let startIndex: Int
  let count: Int
  let startTime: Double
  let zoomStartTime: Double
  let zoomEndTime: Double
  let endTime: Double
  let isAuto: Bool
  let peakZoom: Double
}

func groupZoomRegions(from keyframes: [ZoomKeyframe]) -> [ZoomRegion] {
  guard keyframes.count >= 2 else { return [] }

  var regions: [ZoomRegion] = []
  var i = 0

  while i < keyframes.count {
    if keyframes[i].zoomLevel <= 1.0 && i + 1 < keyframes.count && keyframes[i + 1].zoomLevel > 1.0 {
      let regionStart = i
      var j = i + 1
      var peak = keyframes[j].zoomLevel

      while j < keyframes.count && keyframes[j].zoomLevel > 1.0 {
        peak = max(peak, keyframes[j].zoomLevel)
        j += 1
      }

      let regionEnd: Int
      if j < keyframes.count && keyframes[j].zoomLevel <= 1.0 {
        regionEnd = j
      } else {
        regionEnd = j - 1
      }

      let count = regionEnd - regionStart + 1
      if count >= 2 {
        let zoomStart = keyframes[regionStart + 1].t
        let zoomEnd: Double
        if regionEnd > regionStart + 1 && keyframes[regionEnd].zoomLevel <= 1.0 {
          zoomEnd = keyframes[regionEnd - 1].t
        } else {
          zoomEnd = keyframes[regionEnd].t
        }

        regions.append(
          ZoomRegion(
            startIndex: regionStart,
            count: count,
            startTime: keyframes[regionStart].t,
            zoomStartTime: zoomStart,
            zoomEndTime: zoomEnd,
            endTime: keyframes[regionEnd].t,
            isAuto: keyframes[regionStart].isAuto,
            peakZoom: peak
          )
        )
      }

      i = regionEnd + 1
    } else if keyframes[i].zoomLevel > 1.0 {
      let regionStart = i
      var j = i
      var peak = keyframes[j].zoomLevel

      while j < keyframes.count && keyframes[j].zoomLevel > 1.0 {
        peak = max(peak, keyframes[j].zoomLevel)
        j += 1
      }

      let regionEnd: Int
      if j < keyframes.count && keyframes[j].zoomLevel <= 1.0 {
        regionEnd = j
      } else {
        regionEnd = j - 1
      }

      let count = regionEnd - regionStart + 1
      let zoomEnd: Double
      if regionEnd > regionStart && keyframes[regionEnd].zoomLevel <= 1.0 {
        zoomEnd = keyframes[regionEnd - 1].t
      } else {
        zoomEnd = keyframes[regionEnd].t
      }

      regions.append(
        ZoomRegion(
          startIndex: regionStart,
          count: count,
          startTime: keyframes[regionStart].t,
          zoomStartTime: keyframes[regionStart].t,
          zoomEndTime: zoomEnd,
          endTime: keyframes[regionEnd].t,
          isAuto: keyframes[regionStart].isAuto,
          peakZoom: peak
        )
      )

      i = regionEnd + 1
    } else {
      i += 1
    }
  }

  return regions
}

enum RegionDragType {
  case move, resizeLeft, resizeRight
}

struct RightClickOverlay: NSViewRepresentable {
  let action: () -> Void

  func makeNSView(context: Context) -> RightClickNSView {
    RightClickNSView(action: action)
  }

  func updateNSView(_ nsView: RightClickNSView, context: Context) {
    nsView.action = action
  }

  class RightClickNSView: NSView {
    var action: () -> Void

    init(action: @escaping () -> Void) {
      self.action = action
      super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError()
    }

    override func rightMouseDown(with event: NSEvent) {
      action()
    }
  }
}

private struct RegionEditPopover: View {
  let region: ZoomRegion
  let duration: Double
  let onUpdate: (Int, Int, [ZoomKeyframe]) -> Void
  let onRemove: () -> Void

  @State private var originalKeyframes: [ZoomKeyframe]
  @State private var zoomLevel: Double
  @State private var easeIn: Double
  @State private var easeOut: Double

  @Environment(\.colorScheme) private var colorScheme

  init(
    region: ZoomRegion,
    originalKeyframes: [ZoomKeyframe],
    duration: Double,
    onUpdate: @escaping (Int, Int, [ZoomKeyframe]) -> Void,
    onRemove: @escaping () -> Void
  ) {
    self.region = region
    self.duration = duration
    self.onUpdate = onUpdate
    self.onRemove = onRemove
    _originalKeyframes = State(initialValue: originalKeyframes)
    _zoomLevel = State(initialValue: region.peakZoom)
    _easeIn = State(initialValue: region.zoomStartTime - region.startTime)
    _easeOut = State(initialValue: region.endTime - region.zoomEndTime)
  }

  private var origZoomStartTime: Double {
    originalKeyframes.first(where: { $0.zoomLevel > 1.0 })?.t ?? originalKeyframes.first?.t ?? 0
  }

  private var origZoomEndTime: Double {
    originalKeyframes.last(where: { $0.zoomLevel > 1.0 })?.t ?? originalKeyframes.last?.t ?? 0
  }

  private let popoverLabelWidth: CGFloat = 52

  var body: some View {
    let _ = colorScheme
    VStack(alignment: .leading, spacing: 0) {
      SectionHeader(title: "Zoom")

      HStack {
        Text("Level")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(width: popoverLabelWidth, alignment: .leading)
        Slider(value: $zoomLevel, in: 1.1...5.0, step: 0.1)
        Text(String(format: "%.1fx", zoomLevel))
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(width: 36, alignment: .trailing)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 4)

      Divider()
        .background(ReframedColors.divider)
        .padding(.vertical, 4)

      SectionHeader(title: "Transition")

      HStack {
        Text("Ease In")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(width: popoverLabelWidth, alignment: .leading)
        Slider(value: $easeIn, in: 0.05...2.0, step: 0.05)
        Text(String(format: "%.2fs", easeIn))
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(width: 42, alignment: .trailing)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 4)

      HStack {
        Text("Ease Out")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(width: popoverLabelWidth, alignment: .leading)
        Slider(value: $easeOut, in: 0.05...2.0, step: 0.05)
        Text(String(format: "%.2fs", easeOut))
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(width: 42, alignment: .trailing)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 4)

      Divider()
        .background(ReframedColors.divider)
        .padding(.vertical, 4)

      Button {
        onRemove()
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "trash")
            .font(.system(size: 11))
            .frame(width: 14)
          Text("Remove")
            .font(.system(size: 13))
          Spacer()
        }
        .foregroundStyle(.red.opacity(0.8))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
    .padding(.vertical, 8)
    .frame(width: 260)
    .background(ReframedColors.panelBackground)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .strokeBorder(ReframedColors.subtleBorder, lineWidth: 0.5)
    )
    .onChange(of: zoomLevel) { commitChanges() }
    .onChange(of: easeIn) { commitChanges() }
    .onChange(of: easeOut) { commitChanges() }
  }

  private func commitChanges() {
    guard originalKeyframes.count >= 2 else { return }

    let regionStart = originalKeyframes.first!.t
    let regionEnd = originalKeyframes.last!.t
    let regionSpan = regionEnd - regionStart
    guard regionSpan > 0 else { return }

    let maxEase = regionSpan - 0.02
    let clampedEaseIn = max(0.01, min(easeIn, maxEase))
    let clampedEaseOut = max(0.01, min(easeOut, max(0.01, maxEase - clampedEaseIn)))
    let holdStart = regionStart + clampedEaseIn
    let holdEnd = regionEnd - clampedEaseOut

    let firstZoomIdx = originalKeyframes.firstIndex(where: { $0.zoomLevel > 1.0 })
    let lastZoomIdx = originalKeyframes.lastIndex(where: { $0.zoomLevel > 1.0 })
    let origHoldSpan = origZoomEndTime - origZoomStartTime

    var newKfs = originalKeyframes
    for i in 0..<newKfs.count {
      if newKfs[i].zoomLevel > 1.0 {
        newKfs[i].zoomLevel = zoomLevel
        if i == firstZoomIdx {
          newKfs[i].t = holdStart
        } else if i == lastZoomIdx {
          newKfs[i].t = holdEnd
        } else if origHoldSpan > 0 {
          let frac = (originalKeyframes[i].t - origZoomStartTime) / origHoldSpan
          newKfs[i].t = holdStart + frac * (holdEnd - holdStart)
        }
      }
    }

    onUpdate(region.startIndex, region.count, newKfs)
  }
}

struct ZoomKeyframeEditor: View {
  let keyframes: [ZoomKeyframe]
  let duration: Double
  let width: CGFloat
  let height: CGFloat
  let onAddKeyframe: (Double) -> Void
  let onRemoveRegion: (Int, Int) -> Void
  let onUpdateRegion: (Int, Int, [ZoomKeyframe]) -> Void

  @State private var dragOffset: CGFloat = 0
  @State private var dragType: RegionDragType?
  @State private var dragRegionStartIndex: Int?
  @State private var popoverRegionIndex: Int?

  private var regions: [ZoomRegion] {
    groupZoomRegions(from: keyframes)
  }

  var body: some View {
    ZStack(alignment: .leading) {
      RoundedRectangle(cornerRadius: 10)
        .fill(ReframedColors.panelBackground)
        .frame(width: width, height: height)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { location in
          let fraction = max(0, min(1, location.x / width))
          let time = fraction * duration
          let hitRegion = regions.first { region in
            let startX = (region.startTime / duration) * width
            let endX = (region.endTime / duration) * width
            return location.x >= startX && location.x <= endX
          }
          if hitRegion == nil {
            onAddKeyframe(time)
          }
        }

      if regions.isEmpty {
        Text("Double-click to add zoom region")
          .font(.system(size: 11))
          .foregroundStyle(ReframedColors.dimLabel)
          .frame(width: width, height: height)
          .allowsHitTesting(false)
      }

      ForEach(Array(regions.enumerated()), id: \.offset) { _, region in
        regionView(for: region)
      }
    }
    .frame(width: width, height: height)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .coordinateSpace(name: "zoomEditor")
  }

  private func effectiveTimes(
    for region: ZoomRegion
  ) -> (start: Double, zoomStart: Double, zoomEnd: Double, end: Double) {
    guard dragRegionStartIndex == region.startIndex, let dt = dragType else {
      return (region.startTime, region.zoomStartTime, region.zoomEndTime, region.endTime)
    }
    let timeDelta = (dragOffset / width) * duration

    switch dt {
    case .move:
      return (
        region.startTime + timeDelta,
        region.zoomStartTime + timeDelta,
        region.zoomEndTime + timeDelta,
        region.endTime + timeDelta
      )
    case .resizeLeft:
      let origEaseIn = region.zoomStartTime - region.startTime
      let newStart = max(0, region.startTime + timeDelta)
      var newHoldStart = newStart + origEaseIn
      newHoldStart = min(newHoldStart, region.zoomEndTime - 0.01)
      let clampedStart = min(newStart, newHoldStart)
      return (
        clampedStart,
        newHoldStart,
        region.zoomEndTime,
        region.endTime
      )
    case .resizeRight:
      let origEaseOut = region.endTime - region.zoomEndTime
      let newEnd = min(duration, region.endTime + timeDelta)
      var newHoldEnd = newEnd - origEaseOut
      newHoldEnd = max(newHoldEnd, region.zoomStartTime + 0.01)
      let clampedEnd = max(newEnd, newHoldEnd)
      return (
        region.startTime,
        region.zoomStartTime,
        newHoldEnd,
        clampedEnd
      )
    }
  }

  private func commitDrag(for region: ZoomRegion) {
    guard let dt = dragType else { return }
    let timeDelta = (dragOffset / width) * duration
    var regionKfs = Array(keyframes[region.startIndex..<(region.startIndex + region.count)])

    var proposedStart: Double
    var proposedEnd: Double

    switch dt {
    case .move:
      for i in 0..<regionKfs.count {
        regionKfs[i].t = max(0, min(duration, regionKfs[i].t + timeDelta))
      }
      proposedStart = max(0, region.startTime + timeDelta)
      proposedEnd = min(duration, region.endTime + timeDelta)
    case .resizeLeft:
      let origEaseIn = region.zoomStartTime - region.startTime
      let newStart = max(0, region.startTime + timeDelta)
      var newHoldStart = newStart + origEaseIn
      newHoldStart = min(newHoldStart, region.zoomEndTime - 0.01)
      let clampedStart = min(newStart, newHoldStart)
      if region.endTime - clampedStart < 0.05 { return }
      let firstZoomIdx = regionKfs.firstIndex(where: { $0.zoomLevel > 1.0 })
      for i in 0..<regionKfs.count {
        if regionKfs[i].zoomLevel <= 1.0 && i == 0 {
          regionKfs[i].t = clampedStart
        } else if i == firstZoomIdx {
          regionKfs[i].t = newHoldStart
        }
      }
      proposedStart = clampedStart
      proposedEnd = region.endTime
    case .resizeRight:
      let origEaseOut = region.endTime - region.zoomEndTime
      let newEnd = min(duration, region.endTime + timeDelta)
      var newHoldEnd = newEnd - origEaseOut
      newHoldEnd = max(newHoldEnd, region.zoomStartTime + 0.01)
      let clampedEnd = max(newEnd, newHoldEnd)
      if clampedEnd - region.startTime < 0.05 { return }
      let lastZoomIdx = regionKfs.lastIndex(where: { $0.zoomLevel > 1.0 })
      for i in 0..<regionKfs.count {
        if regionKfs[i].zoomLevel <= 1.0 && i == regionKfs.count - 1 {
          regionKfs[i].t = clampedEnd
        } else if i == lastZoomIdx {
          regionKfs[i].t = newHoldEnd
        }
      }
      proposedStart = region.startTime
      proposedEnd = clampedEnd
    }

    let otherRegions = regions.filter { $0.startIndex != region.startIndex }
    let overlaps = otherRegions.contains { other in
      proposedStart < other.endTime && proposedEnd > other.startTime
    }
    if overlaps { return }

    onUpdateRegion(region.startIndex, region.count, regionKfs)
  }

  @ViewBuilder
  private func regionView(for region: ZoomRegion) -> some View {
    let times = effectiveTimes(for: region)
    let startX = max(0, (times.start / duration) * width)
    let endX = min(width, (times.end / duration) * width)
    let regionWidth = max(4, endX - startX)
    let fillColor = region.isAuto ? ReframedColors.zoomAutoColor : ReframedColors.zoomManualColor
    let easeColor = region.isAuto ? ReframedColors.zoomAutoEaseColor : ReframedColors.zoomManualEaseColor

    let zoomStartX = (times.zoomStart / duration) * width
    let zoomEndX = (times.zoomEnd / duration) * width

    let leadTransWidth = max(0, min(regionWidth, zoomStartX - startX))
    let trailTransWidth = max(0, min(regionWidth - leadTransWidth, endX - zoomEndX))
    let holdWidth = max(0, regionWidth - leadTransWidth - trailTransWidth)

    let edgeThreshold: CGFloat = 8

    HStack(spacing: 0) {
      if leadTransWidth > 0 {
        Rectangle()
          .fill(easeColor)
          .frame(width: leadTransWidth, height: height - 6)
      }

      Rectangle()
        .fill(fillColor)
        .frame(width: holdWidth, height: height - 6)

      if trailTransWidth > 0 {
        Rectangle()
          .fill(easeColor)
          .frame(width: trailTransWidth, height: height - 6)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(fillColor, lineWidth: 2)
    )
    .frame(width: regionWidth, height: height - 6)
    .contentShape(Rectangle())
    .overlay {
      if !region.isAuto {
        RightClickOverlay {
          popoverRegionIndex = region.startIndex
        }
      }
    }
    .gesture(
      DragGesture(minimumDistance: 3, coordinateSpace: .named("zoomEditor"))
        .onChanged { value in
          guard !region.isAuto else { return }
          popoverRegionIndex = nil
          if dragType == nil {
            let origStartX = (region.startTime / duration) * width
            let origEndX = (region.endTime / duration) * width
            let origWidth = origEndX - origStartX
            let relX = value.startLocation.x - origStartX
            if relX <= edgeThreshold && origWidth > edgeThreshold * 3 {
              dragType = .resizeLeft
            } else if relX >= origWidth - edgeThreshold && origWidth > edgeThreshold * 3 {
              dragType = .resizeRight
            } else {
              dragType = .move
            }
            dragRegionStartIndex = region.startIndex
          }
          dragOffset = value.translation.width
        }
        .onEnded { _ in
          guard dragType != nil else { return }
          commitDrag(for: region)
          dragOffset = 0
          dragType = nil
          dragRegionStartIndex = nil
        }
    )
    .popover(
      isPresented: Binding(
        get: { popoverRegionIndex == region.startIndex },
        set: { if !$0 { popoverRegionIndex = nil } }
      )
    ) {
      RegionEditPopover(
        region: region,
        originalKeyframes: Array(keyframes[region.startIndex..<(region.startIndex + region.count)]),
        duration: duration,
        onUpdate: onUpdateRegion,
        onRemove: {
          popoverRegionIndex = nil
          onRemoveRegion(region.startIndex, region.count)
        }
      )
      .presentationBackground(ReframedColors.panelBackground)
    }
    .onContinuousHover { phase in
      guard !region.isAuto else { return }
      switch phase {
      case .active(let location):
        if location.x <= edgeThreshold || location.x >= regionWidth - edgeThreshold {
          NSCursor.resizeLeftRight.set()
        } else {
          NSCursor.openHand.set()
        }
      case .ended:
        NSCursor.arrow.set()
      @unknown default:
        break
      }
    }
    .position(x: startX + regionWidth / 2, y: height / 2)
  }
}
