import Foundation

extension History {
  static let rules: [ChangeRule] = [
    { old, new in
      guard old.trimStartSeconds != new.trimStartSeconds || old.trimEndSeconds != new.trimEndSeconds
      else { return [] }
      return [
        "裁剪范围 \(formatCompactTime(seconds: old.trimStartSeconds))–\(formatCompactTime(seconds: old.trimEndSeconds)) → \(formatCompactTime(seconds: new.trimStartSeconds))–\(formatCompactTime(seconds: new.trimEndSeconds))"
      ]
    },

    prop(\.backgroundStyle) { "背景设为 \(describeBackground($0))" },
    prop(\.backgroundImageFillMode) {
      "背景图片填充方式设为 \(localizedLabel(($0 ?? .fill).label))"
    },

    prop(\.canvasAspect) { "画布比例设为 \(localizedLabel(($0 ?? .original).label))" },
    prop(\.padding) { "画布留白设为 \(Int($0 * 100))%" },

    prop(\.videoCornerRadius) { "视频圆角设为 \(Int($0))px" },
    prop(\.videoShadow) {
      let val = Int($0 ?? 0)
      return val == 0 ? "已移除视频阴影" : "视频阴影设为 \(val)"
    },

    prop(\.cameraAspect) { "摄像头比例设为 \(localizedLabel(($0 ?? .original).label))" },
    prop(\.cameraCornerRadius) { "摄像头圆角设为 \(Int($0))px" },
    prop(\.cameraBorderWidth) { "摄像头边框宽度设为 \(String(format: "%.1f", $0))px" },
    prop(\.cameraBorderColor) { _ in "摄像头边框颜色已更新" },
    prop(\.cameraShadow) {
      let val = Int($0 ?? 0)
      return val == 0 ? "已移除摄像头阴影" : "摄像头阴影设为 \(val)"
    },
    toggle(\.cameraMirrored, default: false, on: "已开启摄像头镜像", off: "已关闭摄像头镜像"),
    prop(\.cameraFullscreenFillMode) {
      "摄像头全屏填充方式设为 \(localizedLabel(($0 ?? .fit).label))"
    },
    prop(\.cameraFullscreenAspect) {
      "摄像头全屏比例设为 \(localizedLabel(($0 ?? .original).label))"
    },
    prop(\.cameraLayout) { _ in "摄像头位置已调整" },
    toggle(\.webcamEnabled, default: true, on: "已启用摄像头", off: "已停用摄像头"),
    prop(\.cameraBackgroundStyle) { "摄像头背景设为 \(describeCameraBackground($0))" },

    { old, new in
      guard old.cursorSettings != new.cursorSettings else { return [] }
      let oldShow = old.cursorSettings?.showCursor ?? true
      let newShow = new.cursorSettings?.showCursor ?? true
      if oldShow != newShow {
        return [newShow ? "已显示光标" : "已隐藏光标"]
      }
      let subRules: [ChangeRule] = [
        sub(\.cursorSettings, \.cursorStyleRaw, default: 0) {
          let style = CursorStyle(rawValue: $0) ?? .centerDefault
          return "光标样式设为 \(localizedLabel(style.label))"
        },
        sub(\.cursorSettings, \.cursorSize, default: CGFloat(24)) { "光标大小设为 \(Int($0))px" },
        subToggle(
          \.cursorSettings,
          \.showClickHighlights,
          default: true,
          on: "已开启点击高亮",
          off: "已关闭点击高亮"
        ),
        { old, new in
          guard
            (old.cursorSettings?.showClickHighlights ?? true)
              == (new.cursorSettings?.showClickHighlights ?? true)
          else { return [] }
          var results: [String] = []
          if old.cursorSettings?.clickHighlightColor != new.cursorSettings?.clickHighlightColor {
            results.append("点击高亮颜色已更新")
          }
          if old.cursorSettings?.clickHighlightSize != new.cursorSettings?.clickHighlightSize {
            results.append(
              "点击高亮大小设为 \(Int(new.cursorSettings?.clickHighlightSize ?? 36))px"
            )
          }
          return results
        },
        sub(\.cursorSettings, \.cursorFillColor, default: nil as CodableColor?) { _ in
          "光标填充色已更新"
        },
        sub(\.cursorSettings, \.cursorStrokeColor, default: nil as CodableColor?) { _ in
          "光标描边色已更新"
        },
        subToggle(
          \.cursorSettings,
          \.spotlightEnabled,
          default: false,
          on: "已开启聚光灯",
          off: "已关闭聚光灯"
        ),
        sub(\.cursorSettings, \.spotlightRadius, default: CGFloat(200)) {
          "聚光灯半径设为 \(Int($0))px"
        },
        sub(\.cursorSettings, \.spotlightDimOpacity, default: CGFloat(0.6)) {
          "聚光灯暗化强度设为 \(Int($0 * 100))%"
        },
        sub(\.cursorSettings, \.spotlightEdgeSoftness, default: CGFloat(50)) {
          "聚光灯边缘柔和度设为 \(Int($0))px"
        },
        subToggle(
          \.cursorSettings,
          \.clickSoundEnabled,
          default: false,
          on: "已开启点击音效",
          off: "已关闭点击音效"
        ),
        sub(\.cursorSettings, \.clickSoundVolume, default: Float(0.5)) {
          "点击音效音量设为 \(Int($0 * 100))%"
        },
        sub(\.cursorSettings, \.clickSoundStyleRaw, default: 0) {
          let style = ClickSoundStyle(rawValue: $0) ?? .click001
          return "点击音效设为 \(localizedLabel(style.label))"
        },
      ]
      return subRules.flatMap { $0(old, new) }
    },

    { old, new in
      guard old.zoomSettings != new.zoomSettings else { return [] }
      let subRules: [ChangeRule] = [
        subToggle(\.zoomSettings, \.zoomEnabled, default: false, on: "已启用缩放", off: "已停用缩放"),
        subToggle(
          \.zoomSettings,
          \.autoZoomEnabled,
          default: false,
          on: "已开启自动缩放",
          off: "已关闭自动缩放"
        ),
        subToggle(
          \.zoomSettings,
          \.zoomFollowCursor,
          default: true,
          on: "已开启缩放跟随光标",
          off: "已关闭缩放跟随光标"
        ),
        sub(\.zoomSettings, \.zoomLevel, default: 2.0) {
          "缩放倍数设为 \(String(format: "%.1f", $0))x"
        },
        sub(\.zoomSettings, \.transitionDuration, default: 0.3) {
          "缩放转场速度设为 \(String(format: "%.1f", $0))s"
        },
        sub(\.zoomSettings, \.dwellThreshold, default: 0.5) {
          "缩放停留阈值设为 \(String(format: "%.1f", $0))s"
        },
        { old, new in
          let o = old.zoomSettings?.keyframes
          let n = new.zoomSettings?.keyframes
          guard o != n else { return [] }
          let oldCount = o?.count ?? 0
          let newCount = n?.count ?? 0
          if newCount > oldCount { return ["已添加缩放关键帧"] }
          if newCount < oldCount { return ["已移除缩放关键帧"] }
          return ["缩放关键帧已调整"]
        },
      ]
      return subRules.flatMap { $0(old, new) }
    },

    { old, new in
      guard old.animationSettings != new.animationSettings else { return [] }
      let subRules: [ChangeRule] = [
        subToggle(
          \.animationSettings,
          \.cursorMovementEnabled,
          default: false,
          on: "已开启光标平滑",
          off: "已关闭光标平滑"
        ),
        sub(\.animationSettings, \.cursorMovementSpeed, default: .medium) {
          "光标平滑速度设为 \(localizedLabel($0.label))"
        },
        subToggle(
          \.animationSettings,
          \.useSystemCursor,
          default: true,
          on: "已启用系统光标",
          off: "已停用系统光标"
        ),
        sub(\.animationSettings, \.clickBounce, default: CGFloat(0)) {
          "点击弹跳设为 \(String(format: "%.1f", $0))"
        },
        sub(\.animationSettings, \.cursorSway, default: CGFloat(0)) {
          "光标摆动设为 \(String(format: "%.2f", $0))"
        },
        sub(\.animationSettings, \.cursorMotionBlur, default: CGFloat(0)) {
          "光标运动模糊设为 \(String(format: "%.1f", $0))"
        },
      ]
      return subRules.flatMap { $0(old, new) }
    },

    { old, new in
      guard old.audioSettings != new.audioSettings else { return [] }
      var results: [String] = []
      let o = old.audioSettings
      let n = new.audioSettings
      if o?.systemAudioVolume != n?.systemAudioVolume || o?.systemAudioMuted != n?.systemAudioMuted {
        if n?.systemAudioMuted == true && o?.systemAudioMuted != true {
          results.append("系统声音已静音")
        } else if n?.systemAudioMuted != true && o?.systemAudioMuted == true {
          results.append("系统声音已取消静音")
        } else {
          results.append("系统声音音量设为 \(Int((n?.systemAudioVolume ?? 1.0) * 100))%")
        }
      }
      if o?.micAudioVolume != n?.micAudioVolume || o?.micAudioMuted != n?.micAudioMuted {
        if n?.micAudioMuted == true && o?.micAudioMuted != true {
          results.append("麦克风已静音")
        } else if n?.micAudioMuted != true && o?.micAudioMuted == true {
          results.append("麦克风已取消静音")
        } else {
          results.append("麦克风音量设为 \(Int((n?.micAudioVolume ?? 1.0) * 100))%")
        }
      }
      let noiseRules: [ChangeRule] = [
        subToggle(
          \.audioSettings,
          \.micNoiseReductionEnabled,
          default: false,
          on: "已开启降噪",
          off: "已关闭降噪"
        ),
        sub(\.audioSettings, \.micNoiseReductionIntensity, default: Float(0.5)) {
          "降噪强度设为 \(Int($0 * 100))%"
        },
      ]
      results.append(contentsOf: noiseRules.flatMap { $0(old, new) })
      return results
    },

    regions(
      \.systemAudioRegions,
      added: "已添加系统声音片段",
      removed: "已移除系统声音片段",
      adjusted: "系统声音片段已调整"
    ),
    regions(
      \.micAudioRegions,
      added: "已添加麦克风片段",
      removed: "已移除麦克风片段",
      adjusted: "麦克风片段已调整"
    ),
    regions(
      \.cameraFullscreenRegions,
      added: "已添加摄像头全屏片段",
      removed: "已移除摄像头全屏片段",
      adjusted: "摄像头全屏片段已调整"
    ),
    regions(
      \.cameraRegions,
      added: "已添加摄像头片段",
      removed: "已移除摄像头片段",
      adjusted: "摄像头片段已调整"
    ),
    regions(
      \.videoRegions,
      added: "已添加视频片段",
      removed: "已移除视频片段",
      adjusted: "视频片段已调整"
    ),
    regions(
      \.spotlightRegions,
      added: "已添加聚光灯片段",
      removed: "已移除聚光灯片段",
      adjusted: "聚光灯片段已调整"
    ),

    { old, new in
      guard old.captionSettings != new.captionSettings || old.captionSegments != new.captionSegments
      else { return [] }
      var results: [String] = []
      let oldSegs = old.captionSegments ?? []
      let newSegs = new.captionSegments ?? []
      if oldSegs.isEmpty && !newSegs.isEmpty {
        return ["已生成字幕（\(newSegs.count) 个片段）"]
      }
      if !oldSegs.isEmpty && newSegs.isEmpty {
        return ["字幕已清空"]
      }
      if oldSegs != newSegs && !oldSegs.isEmpty && !newSegs.isEmpty {
        if oldSegs.count != newSegs.count {
          results.append("字幕片段已更新（\(newSegs.count) 个片段）")
        } else {
          results.append("字幕片段已编辑")
        }
      }
      let subRules: [ChangeRule] = [
        subToggle(
          \.captionSettings,
          \.enabled,
          default: true,
          on: "已启用字幕",
          off: "已停用字幕"
        ),
        sub(\.captionSettings, \.fontSize, default: CGFloat(48)) {
          "字幕字号设为 \(Int($0))px"
        },
        sub(\.captionSettings, \.fontWeight, default: .bold) {
          "字幕字重设为 \(localizedLabel($0.label))"
        },
        sub(\.captionSettings, \.position, default: .bottom) { _ in
          "字幕位置已更新"
        },
        sub(\.captionSettings, \.textColor, default: CodableColor(r: 1, g: 1, b: 1)) { _ in
          "字幕文字颜色已更新"
        },
        sub(
          \.captionSettings,
          \.backgroundColor,
          default: CodableColor(r: 0, g: 0, b: 0, a: 1.0)
        ) { _ in "字幕背景颜色已更新" },
        sub(\.captionSettings, \.backgroundOpacity, default: CGFloat(0.6)) {
          "字幕背景不透明度设为 \(Int($0 * 100))%"
        },
        subToggle(
          \.captionSettings,
          \.showBackground,
          default: true,
          on: "已启用字幕背景",
          off: "已停用字幕背景"
        ),
        sub(\.captionSettings, \.maxWordsPerLine, default: 6) {
          "字幕每行词数设为 \($0)"
        },
        sub(\.captionSettings, \.model, default: "openai_whisper-base") {
          let modelName = WhisperModel(rawValue: $0)?.shortLabel ?? "未知"
          return "字幕模型设为 \(localizedLabel(modelName))"
        },
        sub(\.captionSettings, \.language, default: .auto) {
          "字幕语言设为 \(localizedLabel($0.label))"
        },
        sub(\.captionSettings, \.audioSource, default: .microphone) {
          "字幕音频来源设为 \(localizedLabel($0.label))"
        },
      ]
      results.append(contentsOf: subRules.flatMap { $0(old, new) })
      return results
    },
  ]

  static func describeChanges(from old: EditorStateData, to new: EditorStateData) -> [String] {
    var changes = rules.flatMap { $0(old, new) }
    if changes.isEmpty { changes.append("编辑设置已更新") }
    return changes
  }

  static func describeBackground(_ style: BackgroundStyle) -> String {
    switch style {
    case .none:
      return "无"
    case .gradient(let id):
      if let preset = GradientPresets.preset(for: id) {
        return "\(localizedLabel(preset.name)) 渐变"
      }
      return "渐变"
    case .solidColor:
      return "纯色"
    case .image:
      return "图片"
    }
  }

  static func describeCameraBackground(_ style: CameraBackgroundStyle?) -> String {
    guard let style else { return "无" }
    switch style {
    case .none:
      return "无"
    case .blur:
      return "模糊"
    case .solidColor:
      return "纯色"
    case .gradient(let id):
      if let preset = GradientPresets.preset(for: id) {
        return "\(localizedLabel(preset.name)) 渐变"
      }
      return "渐变"
    case .image:
      return "图片"
    }
  }

  static func localizedLabel(_ label: String) -> String {
    switch label {
    case "Original": return "原始"
    case "Fill": return "填满"
    case "Fit": return "适应"
    case "Default": return "默认"
    case "Secondary": return "次要"
    case "Pointer": return "指针"
    case "Dot": return "圆点"
    case "Circle": return "圆形"
    case "Ring Dot": return "环形点"
    case "Bullseye": return "靶心"
    case "Diamond": return "菱形"
    case "Plus": return "加号"
    case "Crosshair": return "准星"
    case "Cross Dot": return "十字点"
    case "Cross Gap": return "间隔十字"
    case "Spotlight": return "聚光灯"
    case "Brackets": return "括号"
    case "Corners": return "角标"
    case "Square": return "正方形"
    case "Star": return "星形"
    case "Triangle": return "三角形"
    case "Pen": return "钢笔"
    case "Marker": return "马克笔"
    case "Slow": return "慢速"
    case "Medium": return "中等"
    case "Fast": return "快速"
    case "Rapid": return "极快"
    case "Regular": return "常规"
    case "Semibold": return "半粗体"
    case "Bold": return "粗体"
    case "Base": return "基础"
    case "Turbo": return "极速"
    case "Microphone": return "麦克风"
    case "System Audio": return "系统声音"
    case "Auto-detect": return "自动检测"
    case "Chinese": return "中文"
    case "English": return "英语"
    default: return NSLocalizedString(label, comment: "")
    }
  }
}
