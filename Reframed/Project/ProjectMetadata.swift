import AppKit
import CoreGraphics
import CoreText
import Foundation
import SwiftUI

struct ProjectMetadata: Codable, Sendable {
  var version: Int = 1
  var name: String?
  var createdAt: Date
  var fps: Int
  var screenSize: CodableSize
  var webcamSize: CodableSize?
  var hasSystemAudio: Bool
  var hasMicrophoneAudio: Bool
  var hasCursorMetadata: Bool = false
  var hasWebcam: Bool = false
  var captureMode: CaptureMode?
  var captureQuality: String? = nil
  var isHDR: Bool = false
  var editorState: EditorStateData?
}

struct CursorSettingsData: Codable, Sendable, Equatable {
  var showCursor: Bool
  var cursorStyleRaw: Int
  var cursorSize: CGFloat
  var cursorFillColor: CodableColor?
  var cursorStrokeColor: CodableColor?
  var showClickHighlights: Bool = true
  var clickHighlightColor: CodableColor? = nil
  var clickHighlightSize: CGFloat = 36
  var spotlightEnabled: Bool = false
  var spotlightRadius: CGFloat = 200
  var spotlightDimOpacity: CGFloat = 0.6
  var spotlightEdgeSoftness: CGFloat = 50
  var clickSoundEnabled: Bool = false
  var clickSoundVolume: Float = 0.5
  var clickSoundStyleRaw: Int = 0
}

struct ZoomSettingsData: Codable, Sendable, Equatable {
  var zoomEnabled: Bool = false
  var autoZoomEnabled: Bool
  var zoomFollowCursor: Bool = true
  var zoomLevel: Double
  var transitionDuration: Double
  var dwellThreshold: Double
  var keyframes: [ZoomKeyframe]
}

struct AnimationSettingsData: Codable, Sendable, Equatable {
  var cursorMovementEnabled: Bool = false
  var cursorMovementSpeed: CursorMovementSpeed = .medium
}

struct AudioSettingsData: Codable, Sendable, Equatable {
  var systemAudioVolume: Float = 1.0
  var micAudioVolume: Float = 1.0
  var systemAudioMuted: Bool = false
  var micAudioMuted: Bool = false
  var micNoiseReductionEnabled: Bool = false
  var micNoiseReductionIntensity: Float = 0.5
  var cachedNoiseReductionIntensity: Float?
}

struct AudioRegionData: Codable, Sendable, Identifiable, Equatable {
  var id: UUID = UUID()
  var startSeconds: Double
  var endSeconds: Double
}

struct SpotlightRegionData: Codable, Sendable, Identifiable, Equatable {
  var id: UUID = UUID()
  var startSeconds: Double
  var endSeconds: Double
  var customRadius: CGFloat?
  var customDimOpacity: CGFloat?
  var customEdgeSoftness: CGFloat?
  var fadeDuration: Double?
}

enum RegionTransitionType: String, Codable, Sendable, CaseIterable, Identifiable {
  case none, fade, scale, slide

  var id: String { rawValue }

  var label: String {
    switch self {
    case .none: "None"
    case .fade: "Fade"
    case .scale: "Scale"
    case .slide: "Slide"
    }
  }
}

enum CameraRegionType: String, Codable, Sendable, CaseIterable, Identifiable {
  case fullscreen
  case hidden
  case custom

  var id: String { rawValue }

  var label: String {
    switch self {
    case .fullscreen: "Fullscreen"
    case .hidden: "Hidden"
    case .custom: "Custom"
    }
  }

  var icon: String {
    switch self {
    case .fullscreen: "arrow.up.left.and.arrow.down.right"
    case .hidden: "eye.slash"
    case .custom: "pip"
    }
  }
}

struct CameraRegionData: Codable, Sendable, Identifiable, Equatable {
  var id: UUID = UUID()
  var startSeconds: Double
  var endSeconds: Double
  var type: CameraRegionType = .fullscreen
  var customLayout: CameraLayout?
  var customCameraAspect: CameraAspect?
  var customCornerRadius: CGFloat?
  var customShadow: CGFloat?
  var customBorderWidth: CGFloat?
  var customBorderColor: CodableColor?
  var customMirrored: Bool?
  var entryTransition: RegionTransitionType?
  var entryTransitionDuration: Double?
  var exitTransition: RegionTransitionType?
  var exitTransitionDuration: Double?
}

struct VideoRegionData: Codable, Sendable, Identifiable, Equatable {
  var id: UUID = UUID()
  var startSeconds: Double
  var endSeconds: Double
  var entryTransition: RegionTransitionType?
  var entryTransitionDuration: Double?
  var exitTransition: RegionTransitionType?
  var exitTransitionDuration: Double?
}

struct CaptionSegment: Codable, Sendable, Identifiable, Equatable {
  var id: UUID = UUID()
  var startSeconds: Double
  var endSeconds: Double
  var text: String
  var words: [CaptionWord]?
}

struct CaptionWord: Codable, Sendable, Equatable {
  var word: String
  var startSeconds: Double
  var endSeconds: Double
}

struct CaptionPosition: Codable, Sendable, Equatable {
  var relativeX: CGFloat
  var relativeY: CGFloat

  static let bottom = CaptionPosition(relativeX: 0.5, relativeY: 0.9)
  static let top = CaptionPosition(relativeX: 0.5, relativeY: 0.1)
  static let center = CaptionPosition(relativeX: 0.5, relativeY: 0.5)

  static let presets: [(label: String, position: CaptionPosition)] = [
    ("Bottom", .bottom),
    ("Center", .center),
    ("Top", .top),
  ]

  init(relativeX: CGFloat = 0.5, relativeY: CGFloat = 0.9) {
    self.relativeX = min(1, max(0, relativeX))
    self.relativeY = min(1, max(0, relativeY))
  }

  init(from decoder: Decoder) throws {
    if let container = try? decoder.singleValueContainer(),
      let raw = try? container.decode(String.self)
    {
      switch raw {
      case "top": self = .top
      case "center": self = .center
      default: self = .bottom
      }
      return
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    relativeX = min(1, max(0, try container.decode(CGFloat.self, forKey: .relativeX)))
    relativeY = min(1, max(0, try container.decode(CGFloat.self, forKey: .relativeY)))
  }

  enum CodingKeys: String, CodingKey {
    case relativeX, relativeY
  }
}

enum CaptionLayout {
  static let paddingHRatio: CGFloat = 0.4
  static let paddingVRatio: CGFloat = 0.2
  static let maxWidthRatio: CGFloat = 0.9
  static let maxHeightRatio: CGFloat = 0.08
  static let minFontSize: CGFloat = 12

  static func scaledFontSize(
    fontSize: CGFloat,
    canvasWidth: CGFloat,
    canvasHeight: CGFloat,
    screenWidth: CGFloat
  ) -> CGFloat {
    let raw = fontSize * (canvasWidth / max(screenWidth, 1))
    return max(minFontSize, min(raw, canvasHeight * maxHeightRatio))
  }

  static func measureText(
    _ text: String,
    scaledFontSize: CGFloat,
    fontWeight: CaptionFontWeight,
    maxTextWidth: CGFloat
  ) -> CGSize {
    let nsFont = NSFont.systemFont(ofSize: scaledFontSize, weight: fontWeight.nsWeight)
    let ctFont = CTFontCreateWithName(nsFont.fontName as CFString, scaledFontSize, nil)
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
      .font: ctFont,
      NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraphStyle,
    ]
    let attrString = NSAttributedString(string: text, attributes: attributes)
    let frameSetter = CTFramesetterCreateWithAttributedString(attrString)
    let lineHeight = CTFontGetAscent(ctFont) + CTFontGetDescent(ctFont) + CTFontGetLeading(ctFont)
    let measurPath = CGPath(
      rect: CGRect(x: 0, y: 0, width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude),
      transform: nil
    )
    let measurFrame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, 0), measurPath, nil)
    let ctLines = CTFrameGetLines(measurFrame) as? [CTLine] ?? []
    let actualLineCount = max(ctLines.count, 1)
    var maxLineWidth: CGFloat = 0
    for line in ctLines {
      maxLineWidth = max(maxLineWidth, CTLineGetTypographicBounds(line, nil, nil, nil))
    }
    let suggestedSize = CGSize(
      width: ceil(maxLineWidth),
      height: ceil(lineHeight * CGFloat(actualLineCount))
    )
    let paddingH = scaledFontSize * paddingHRatio
    let paddingV = scaledFontSize * paddingVRatio
    return CGSize(
      width: suggestedSize.width + paddingH * 2,
      height: suggestedSize.height + paddingV * 2
    )
  }
}

enum CaptionFontWeight: String, Codable, Sendable, CaseIterable, Identifiable {
  case regular, medium, semibold, bold

  var id: String { rawValue }

  var label: String {
    switch self {
    case .regular: "Regular"
    case .medium: "Medium"
    case .semibold: "Semibold"
    case .bold: "Bold"
    }
  }

  var nsWeight: NSFont.Weight {
    switch self {
    case .regular: .regular
    case .medium: .medium
    case .semibold: .semibold
    case .bold: .bold
    }
  }

  var swiftUIWeight: Font.Weight {
    switch self {
    case .regular: .regular
    case .medium: .medium
    case .semibold: .semibold
    case .bold: .bold
    }
  }
}

enum CaptionLanguage: String, Codable, Sendable, CaseIterable, Identifiable {
  case auto
  case en, zh, de, es, ru, ko, fr, ja, pt, tr, pl, ca, nl, ar, sv, it, id, hi, fi, vi, he, uk, el
  case ms, cs, ro, da, hu, ta, no, th, ur, hr, bg, lt, la, mi, ml, cy, sk, te, fa, lv, bn, sr, az
  case sl, kn, et, mk, br, eu, `is`, hy, ne, mn, bs, kk, sq, sw, gl, mr, pa, si, km, sn, yo, so
  case af, oc, ka, be, tg, sd, gu, am, yi, lo, uz, fo, ht, ps, tk, nn, mt, sa, lb, my, bo, tl
  case mg, `as`, tt, haw, ln, ha, ba, jw, su, yue

  var id: String { rawValue }

  var label: String {
    switch self {
    case .auto: "Auto-detect"
    case .en: "English"
    case .zh: "Chinese"
    case .de: "German"
    case .es: "Spanish"
    case .ru: "Russian"
    case .ko: "Korean"
    case .fr: "French"
    case .ja: "Japanese"
    case .pt: "Portuguese"
    case .tr: "Turkish"
    case .pl: "Polish"
    case .ca: "Catalan"
    case .nl: "Dutch"
    case .ar: "Arabic"
    case .sv: "Swedish"
    case .it: "Italian"
    case .id: "Indonesian"
    case .hi: "Hindi"
    case .fi: "Finnish"
    case .vi: "Vietnamese"
    case .he: "Hebrew"
    case .uk: "Ukrainian"
    case .el: "Greek"
    case .ms: "Malay"
    case .cs: "Czech"
    case .ro: "Romanian"
    case .da: "Danish"
    case .hu: "Hungarian"
    case .ta: "Tamil"
    case .no: "Norwegian"
    case .th: "Thai"
    case .ur: "Urdu"
    case .hr: "Croatian"
    case .bg: "Bulgarian"
    case .lt: "Lithuanian"
    case .la: "Latin"
    case .mi: "Maori"
    case .ml: "Malayalam"
    case .cy: "Welsh"
    case .sk: "Slovak"
    case .te: "Telugu"
    case .fa: "Persian"
    case .lv: "Latvian"
    case .bn: "Bengali"
    case .sr: "Serbian"
    case .az: "Azerbaijani"
    case .sl: "Slovenian"
    case .kn: "Kannada"
    case .et: "Estonian"
    case .mk: "Macedonian"
    case .br: "Breton"
    case .eu: "Basque"
    case .is: "Icelandic"
    case .hy: "Armenian"
    case .ne: "Nepali"
    case .mn: "Mongolian"
    case .bs: "Bosnian"
    case .kk: "Kazakh"
    case .sq: "Albanian"
    case .sw: "Swahili"
    case .gl: "Galician"
    case .mr: "Marathi"
    case .pa: "Punjabi"
    case .si: "Sinhala"
    case .km: "Khmer"
    case .sn: "Shona"
    case .yo: "Yoruba"
    case .so: "Somali"
    case .af: "Afrikaans"
    case .oc: "Occitan"
    case .ka: "Georgian"
    case .be: "Belarusian"
    case .tg: "Tajik"
    case .sd: "Sindhi"
    case .gu: "Gujarati"
    case .am: "Amharic"
    case .yi: "Yiddish"
    case .lo: "Lao"
    case .uz: "Uzbek"
    case .fo: "Faroese"
    case .ht: "Haitian Creole"
    case .ps: "Pashto"
    case .tk: "Turkmen"
    case .nn: "Nynorsk"
    case .mt: "Maltese"
    case .sa: "Sanskrit"
    case .lb: "Luxembourgish"
    case .my: "Myanmar"
    case .bo: "Tibetan"
    case .tl: "Tagalog"
    case .mg: "Malagasy"
    case .as: "Assamese"
    case .tt: "Tatar"
    case .haw: "Hawaiian"
    case .ln: "Lingala"
    case .ha: "Hausa"
    case .ba: "Bashkir"
    case .jw: "Javanese"
    case .su: "Sundanese"
    case .yue: "Cantonese"
    }
  }

  var whisperCode: String? {
    self == .auto ? nil : rawValue
  }

  static var sortedCases: [CaptionLanguage] {
    let rest = allCases.filter { $0 != .auto }.sorted { $0.label < $1.label }
    return [.auto] + rest
  }
}

enum CaptionAudioSource: String, Codable, Sendable, CaseIterable, Identifiable, Equatable {
  case microphone
  case system

  var id: String { rawValue }

  var label: String {
    switch self {
    case .microphone: "Microphone"
    case .system: "System Audio"
    }
  }
}

struct CaptionSettingsData: Codable, Sendable, Equatable {
  var enabled: Bool = true
  var fontSize: CGFloat = 48
  var fontWeight: CaptionFontWeight = .bold
  var textColor: CodableColor = CodableColor(r: 1, g: 1, b: 1)
  var backgroundColor: CodableColor = CodableColor(r: 0, g: 0, b: 0, a: 1.0)
  var backgroundOpacity: CGFloat = 0.6
  var showBackground: Bool = true
  var position: CaptionPosition = .bottom
  var maxWordsPerLine: Int = 6
  var model: String = "openai_whisper-base"
  var language: CaptionLanguage = .auto
  var audioSource: CaptionAudioSource = .microphone
}

struct EditorStateData: Codable, Sendable {
  var trimStartSeconds: Double
  var trimEndSeconds: Double
  var backgroundStyle: BackgroundStyle
  var backgroundImageFillMode: BackgroundImageFillMode?
  var canvasAspect: CanvasAspect?
  var padding: CGFloat
  var videoCornerRadius: CGFloat
  var cameraAspect: CameraAspect?
  var cameraCornerRadius: CGFloat
  var cameraBorderWidth: CGFloat
  var cameraBorderColor: CodableColor?
  var videoShadow: CGFloat?
  var cameraShadow: CGFloat?
  var cameraMirrored: Bool?
  var cameraFullscreenFillMode: CameraFullscreenFillMode?
  var cameraFullscreenAspect: CameraFullscreenAspect?
  var cameraLayout: CameraLayout
  var webcamEnabled: Bool?
  var cursorSettings: CursorSettingsData?
  var zoomSettings: ZoomSettingsData?
  var animationSettings: AnimationSettingsData?
  var audioSettings: AudioSettingsData?
  var systemAudioRegions: [AudioRegionData]?
  var micAudioRegions: [AudioRegionData]?
  var cameraRegions: [CameraRegionData]?
  var cameraFullscreenRegions: [AudioRegionData]?
  var videoRegions: [VideoRegionData]?
  var cameraBackgroundStyle: CameraBackgroundStyle?
  var captionSettings: CaptionSettingsData?
  var captionSegments: [CaptionSegment]?
  var spotlightRegions: [SpotlightRegionData]?
}

struct CodableSize: Codable, Sendable {
  var width: CGFloat
  var height: CGFloat

  init(_ size: CGSize) {
    self.width = size.width
    self.height = size.height
  }

  var cgSize: CGSize {
    CGSize(width: width, height: height)
  }
}

// MARK: - Lenient Decoders
// Moving init(from:) into extensions preserves the auto-generated memberwise init.
// Use `c.decodeOrDefault( .key,value)` from LenientCodable.swift for fields that
// may be missing from older project.json files. To add a new field with a default,
// just add the property above and a decode line below.

extension ProjectMetadata {
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    version = try c.decodeOrDefault(.version, 1)
    name = try c.decodeIfPresent(String.self, forKey: .name)
    createdAt = try c.decode(Date.self, forKey: .createdAt)
    fps = try c.decode(Int.self, forKey: .fps)
    screenSize = try c.decode(CodableSize.self, forKey: .screenSize)
    webcamSize = try c.decodeIfPresent(CodableSize.self, forKey: .webcamSize)
    hasSystemAudio = try c.decode(Bool.self, forKey: .hasSystemAudio)
    hasMicrophoneAudio = try c.decode(Bool.self, forKey: .hasMicrophoneAudio)
    hasCursorMetadata = try c.decodeOrDefault(.hasCursorMetadata, false)
    hasWebcam = try c.decodeOrDefault(.hasWebcam, false)
    captureMode = try c.decodeIfPresent(CaptureMode.self, forKey: .captureMode)
    captureQuality = try c.decodeIfPresent(String.self, forKey: .captureQuality)
    isHDR = try c.decodeOrDefault(.isHDR, false)
    editorState = try c.decodeIfPresent(EditorStateData.self, forKey: .editorState)
  }
}

extension CursorSettingsData {
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    showCursor = try c.decode(Bool.self, forKey: .showCursor)
    cursorStyleRaw = try c.decode(Int.self, forKey: .cursorStyleRaw)
    cursorSize = try c.decode(CGFloat.self, forKey: .cursorSize)
    cursorFillColor = try c.decodeIfPresent(CodableColor.self, forKey: .cursorFillColor)
    cursorStrokeColor = try c.decodeIfPresent(CodableColor.self, forKey: .cursorStrokeColor)
    showClickHighlights = try c.decodeOrDefault(.showClickHighlights, true)
    clickHighlightColor = try c.decodeIfPresent(CodableColor.self, forKey: .clickHighlightColor)
    clickHighlightSize = try c.decodeOrDefault(.clickHighlightSize, 36)
    spotlightEnabled = try c.decodeOrDefault(.spotlightEnabled, false)
    spotlightRadius = try c.decodeOrDefault(.spotlightRadius, 200)
    spotlightDimOpacity = try c.decodeOrDefault(.spotlightDimOpacity, 0.6)
    spotlightEdgeSoftness = try c.decodeOrDefault(.spotlightEdgeSoftness, 50)
    clickSoundEnabled = try c.decodeOrDefault(.clickSoundEnabled, false)
    clickSoundVolume = try c.decodeOrDefault(.clickSoundVolume, 0.5)
    clickSoundStyleRaw = try c.decodeOrDefault(.clickSoundStyleRaw, 0)
  }
}

extension ZoomSettingsData {
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    zoomEnabled = try c.decodeOrDefault(.zoomEnabled, false)
    autoZoomEnabled = try c.decode(Bool.self, forKey: .autoZoomEnabled)
    zoomFollowCursor = try c.decodeOrDefault(.zoomFollowCursor, true)
    zoomLevel = try c.decode(Double.self, forKey: .zoomLevel)
    transitionDuration = try c.decode(Double.self, forKey: .transitionDuration)
    dwellThreshold = try c.decode(Double.self, forKey: .dwellThreshold)
    keyframes = try c.decode([ZoomKeyframe].self, forKey: .keyframes)
  }
}

extension AnimationSettingsData {
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    cursorMovementEnabled = try c.decodeOrDefault(.cursorMovementEnabled, false)
    cursorMovementSpeed = try c.decodeOrDefault(.cursorMovementSpeed, .medium)
  }
}

extension AudioSettingsData {
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    systemAudioVolume = try c.decodeOrDefault(.systemAudioVolume, 1.0)
    micAudioVolume = try c.decodeOrDefault(.micAudioVolume, 1.0)
    systemAudioMuted = try c.decodeOrDefault(.systemAudioMuted, false)
    micAudioMuted = try c.decodeOrDefault(.micAudioMuted, false)
    micNoiseReductionEnabled = try c.decodeOrDefault(.micNoiseReductionEnabled, false)
    micNoiseReductionIntensity = try c.decodeOrDefault(.micNoiseReductionIntensity, 0.5)
    cachedNoiseReductionIntensity = try c.decodeIfPresent(Float.self, forKey: .cachedNoiseReductionIntensity)
  }
}

extension CaptionSettingsData {
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    enabled = try c.decodeOrDefault(.enabled, true)
    fontSize = try c.decodeOrDefault(.fontSize, 48)
    fontWeight = try c.decodeOrDefault(.fontWeight, .bold)
    textColor = try c.decodeOrDefault(.textColor, CodableColor(r: 1, g: 1, b: 1))
    backgroundColor = try c.decodeOrDefault(.backgroundColor, CodableColor(r: 0, g: 0, b: 0, a: 1.0))
    backgroundOpacity = try c.decodeOrDefault(.backgroundOpacity, 0.6)
    showBackground = try c.decodeOrDefault(.showBackground, true)
    position = try c.decodeOrDefault(.position, .bottom)
    maxWordsPerLine = try c.decodeOrDefault(.maxWordsPerLine, 6)
    model = try c.decodeOrDefault(.model, "openai_whisper-base")
    language = try c.decodeOrDefault(.language, .auto)
    audioSource = try c.decodeOrDefault(.audioSource, .microphone)
  }
}
