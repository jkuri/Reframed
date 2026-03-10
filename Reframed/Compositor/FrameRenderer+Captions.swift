import AVFoundation
import AppKit
import CoreText

extension FrameRenderer {
  static func drawCaptions(
    in context: CGContext,
    videoRect: CGRect,
    canvasRect: CGRect,
    instruction: CompositionInstruction,
    compositionTime: CMTime
  ) {
    guard instruction.captionsEnabled, !instruction.captionSegments.isEmpty else { return }

    let time = CMTimeGetSeconds(compositionTime) + instruction.trimStartSeconds
    guard
      let segment = captionSegmentAt(
        time: time,
        in: instruction.captionSegments
      )
    else { return }

    let displayText = visibleText(
      for: segment,
      at: time,
      maxWordsPerLine: instruction.captionMaxWordsPerLine
    )
    guard !displayText.isEmpty else { return }

    let fontSize = instruction.captionFontSize * (videoRect.width / 1920.0)
    let clampedFontSize = max(12, min(fontSize, videoRect.height * 0.08))

    let nsWeight: NSFont.Weight = {
      switch instruction.captionFontWeight {
      case .regular: return .regular
      case .medium: return .medium
      case .semibold: return .semibold
      case .bold: return .bold
      }
    }()
    let nsFont = NSFont.systemFont(ofSize: clampedFontSize, weight: nsWeight)
    let weightedFont = CTFontCreateWithName(nsFont.fontName as CFString, clampedFontSize, nil)

    let textColor = instruction.captionTextColor
    let cgTextColor = CGColor(
      srgbRed: textColor.r,
      green: textColor.g,
      blue: textColor.b,
      alpha: textColor.a
    )

    var alignment = CTTextAlignment.center
    let paragraphStyle = withUnsafeMutablePointer(to: &alignment) { alignPtr in
      let setting = CTParagraphStyleSetting(
        spec: .alignment,
        valueSize: MemoryLayout<CTTextAlignment>.size,
        value: alignPtr
      )
      return withUnsafePointer(to: setting) { ptr in
        CTParagraphStyleCreate(ptr, 1)
      }
    }

    let attributes: [NSAttributedString.Key: Any] = [
      .font: weightedFont,
      .foregroundColor: cgTextColor,
      NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraphStyle,
    ]

    let attrString = NSAttributedString(string: displayText, attributes: attributes)

    let maxTextWidth = videoRect.width * 0.9
    let frameSetter = CTFramesetterCreateWithAttributedString(attrString)
    let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
      frameSetter,
      CFRangeMake(0, 0),
      nil,
      CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
      nil
    )

    let paddingH = clampedFontSize * 0.4
    let paddingV = clampedFontSize * 0.2
    let bgWidth = suggestedSize.width + paddingH * 2
    let bgHeight = suggestedSize.height + paddingV * 2

    let bgX = canvasRect.midX - bgWidth / 2
    let bgY: CGFloat = {
      switch instruction.captionPosition {
      case .bottom:
        return canvasRect.minY + canvasRect.height * 0.05
      case .top:
        return canvasRect.maxY - canvasRect.height * 0.05 - bgHeight
      case .center:
        return canvasRect.midY - bgHeight / 2
      }
    }()

    let bgRect = CGRect(x: bgX, y: bgY, width: bgWidth, height: bgHeight)

    if instruction.captionShowBackground {
      let bgColor = instruction.captionBackgroundColor
      let cgBgColor = CGColor(
        srgbRed: bgColor.r,
        green: bgColor.g,
        blue: bgColor.b,
        alpha: bgColor.a * instruction.captionBackgroundOpacity
      )
      let cornerRadius = clampedFontSize * 0.2
      let bgPath = CGPath(
        roundedRect: bgRect,
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
      )
      context.saveGState()
      context.setFillColor(cgBgColor)
      context.addPath(bgPath)
      context.fillPath()
      context.restoreGState()
    }

    let textRect = CGRect(
      x: bgRect.origin.x + paddingH,
      y: bgRect.origin.y + paddingV,
      width: suggestedSize.width,
      height: suggestedSize.height
    )
    let path = CGPath(rect: textRect, transform: nil)
    let frame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, 0), path, nil)

    context.saveGState()
    context.textMatrix = .identity
    CTFrameDraw(frame, context)
    context.restoreGState()
  }

  static func captionSegmentAt(
    time: Double,
    in segments: [CaptionSegment]
  ) -> CaptionSegment? {
    if let segment = segments.first(where: {
      time >= $0.startSeconds && time < $0.endSeconds
    }) {
      return segment
    }

    let maxLinger = 1.5
    guard
      let previous = segments.last(where: { $0.endSeconds <= time }),
      time - previous.endSeconds < maxLinger
    else { return nil }

    let nextStart = segments.first(where: { $0.startSeconds > time })?.startSeconds
    if let nextStart, time >= nextStart {
      return nil
    }

    return previous
  }

  private static func visibleText(
    for segment: CaptionSegment,
    at time: Double,
    maxWordsPerLine: Int
  ) -> String {
    let words: [String]
    if let segmentWords = segment.words, !segmentWords.isEmpty {
      words = segmentWords.map(\.word)
    } else {
      words = segment.text.split(separator: " ").map(String.init)
    }

    guard !words.isEmpty else { return segment.text }

    if words.count <= maxWordsPerLine {
      return words.joined(separator: " ")
    }

    var lines: [String] = []
    var i = 0
    while i < words.count {
      let chunk = words[i..<min(i + maxWordsPerLine, words.count)]
      lines.append(chunk.joined(separator: " "))
      i += maxWordsPerLine
    }

    let totalLines = lines.count
    let segmentDuration = segment.endSeconds - segment.startSeconds
    guard segmentDuration > 0 else { return lines.prefix(2).joined(separator: "\n") }

    let linesPerWindow = 2
    let windowCount = max(1, Int(ceil(Double(totalLines) / Double(linesPerWindow))))
    let windowDuration = segmentDuration / Double(windowCount)
    let windowStart = time - segment.startSeconds
    let windowIndex = min(Int(windowStart / windowDuration), windowCount - 1)
    let lineStart = windowIndex * linesPerWindow
    let visibleLines = lines[lineStart..<min(lineStart + linesPerWindow, totalLines)]
    return visibleLines.joined(separator: "\n")
  }
}
