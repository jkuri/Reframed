import AVFoundation
import SwiftUI

extension PropertiesPanel {
  var projectSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: Layout.itemSpacing) {
        SectionHeader(icon: "doc.text", title: "Project")

        InlineEditableText(
          text: editorState.projectName,
          onCommit: { newName in
            editorState.renameProject(newName)
          }
        )
      }

      recordingInfoSection
    }
  }

  var recordingInfoSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "info.circle", title: "Recording Info")

      VStack(spacing: Layout.compactSpacing) {
        infoRow("Duration", value: formatDuration(editorState.duration))

        if let mode = editorState.project?.metadata.captureMode, mode != .none {
          infoRow("Capture Mode", value: captureModeLabel(mode))
        }

        infoRow("Project Size", value: formattedProjectSize())
        infoRow("Cursor Data", value: yesNo(editorState.cursorMetadataProvider != nil))

        if let date = editorState.project?.metadata.createdAt {
          infoRow("Recorded", value: formattedDate(date))
        }
      }

      screenTrackSection
      webcamTrackSection
      systemAudioTrackSection
      micAudioTrackSection
    }
    .task { await loadMediaInfo() }
  }

  var screenTrackSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "rectangle.on.rectangle", title: "Screen Capture")

      VStack(spacing: Layout.compactSpacing) {
        infoRow("Resolution", value: "\(Int(editorState.result.screenSize.width))x\(Int(editorState.result.screenSize.height))")
        infoRow("FPS", value: "\(editorState.result.fps)")
        infoRow("Codec", value: codecLabel(editorState.result.captureQuality))
        infoRow("HDR", value: yesNo(editorState.result.isHDR))
        if let info = screenInfo {
          infoRow("Size", value: info.fileSize)
          if let bitrate = info.bitrate {
            infoRow("Bitrate", value: bitrate)
          }
        }
      }
    }
  }

  @ViewBuilder
  var webcamTrackSection: some View {
    if editorState.result.webcamSize != nil {
      VStack(alignment: .leading, spacing: Layout.itemSpacing) {
        SectionHeader(icon: "web.camera", title: "Camera")

        VStack(spacing: Layout.compactSpacing) {
          if let ws = editorState.result.webcamSize {
            infoRow("Resolution", value: "\(Int(ws.width))x\(Int(ws.height))")
          }
          if let info = webcamInfo {
            if let fps = info.fps {
              infoRow("FPS", value: fps)
            }
            infoRow("Size", value: info.fileSize)
            if let bitrate = info.bitrate {
              infoRow("Bitrate", value: bitrate)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  var systemAudioTrackSection: some View {
    if editorState.result.systemAudioURL != nil {
      VStack(alignment: .leading, spacing: Layout.itemSpacing) {
        SectionHeader(icon: "speaker.wave.2", title: "System Audio")

        VStack(spacing: Layout.compactSpacing) {
          if let info = systemAudioInfo {
            infoRow("Size", value: info.fileSize)
            if let bitrate = info.bitrate {
              infoRow("Bitrate", value: bitrate)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  var micAudioTrackSection: some View {
    if editorState.result.microphoneAudioURL != nil {
      VStack(alignment: .leading, spacing: Layout.itemSpacing) {
        SectionHeader(icon: "mic", title: "Microphone")

        VStack(spacing: Layout.compactSpacing) {
          if let info = micAudioInfo {
            infoRow("Size", value: info.fileSize)
            if let bitrate = info.bitrate {
              infoRow("Bitrate", value: bitrate)
            }
          }
        }
      }
    }
  }

  func loadMediaInfo() async {
    let result = editorState.result
    screenInfo = await MediaFileInfo.load(url: result.screenVideoURL)
    if let url = result.webcamVideoURL {
      webcamInfo = await MediaFileInfo.load(url: url)
    }
    if let url = result.systemAudioURL {
      systemAudioInfo = await MediaFileInfo.load(url: url)
    }
    if let url = result.microphoneAudioURL {
      micAudioInfo = await MediaFileInfo.load(url: url)
    }
  }

  func codecLabel(_ quality: CaptureQuality) -> String {
    switch quality {
    case .standard: "H.265 (HEVC)"
    case .high: "ProRes 422"
    case .veryHigh: "ProRes 4444"
    }
  }

  func captureModeLabel(_ mode: CaptureMode) -> String {
    switch mode {
    case .none: "无"
    case .entireScreen: "整个屏幕"
    case .selectedWindow: "窗口"
    case .selectedArea: "区域"
    case .device: "iOS 设备"
    }
  }

  func yesNo(_ value: Bool) -> String {
    value ? "是" : "否"
  }

  func formattedProjectSize() -> String {
    guard let bundleURL = editorState.project?.bundleURL else { return "—" }
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(at: bundleURL, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
      return "—"
    }
    var total: Int64 = 0
    for case let fileURL as URL in enumerator {
      if let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
        total += Int64(size)
      }
    }
    return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
  }

  func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  func infoRow(_ label: String, value: String) -> some View {
    HStack {
      Text(LocalizedStringKey(label))
        .font(.system(size: FontSize.xs))
        .foregroundStyle(ReframedColors.secondaryText)
      Spacer()
      Text(value)
        .font(.system(size: FontSize.xs))
        .foregroundStyle(ReframedColors.secondaryText)
    }
  }
}
