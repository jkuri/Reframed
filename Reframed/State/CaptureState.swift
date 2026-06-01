import Foundation

enum CaptureState: Sendable, Equatable {
  case idle
  case selecting
  case countdown(remaining: Int)
  case recording(startedAt: Date)
  case paused(elapsed: TimeInterval)
  case processing
  case editing
}

enum CaptureError: LocalizedError {
  case invalidTransition(from: String, to: String)
  case noSelectionStored
  case displayNotFound
  case permissionDenied
  case recordingFailed(String)
  case microphoneNotFound
  case cameraNotFound
  case cameraStreamFailed
  case microphoneStreamFailed
  case deviceNotFound
  case deviceStreamFailed

  var errorDescription: String? {
    switch self {
    case .invalidTransition(let from, let to):
      return "状态切换无效：从 \(from) 切换到 \(to)"
    case .noSelectionStored:
      return "还没有选择屏幕区域"
    case .displayNotFound:
      return "找不到目标显示器"
    case .permissionDenied:
      return "需要屏幕录制权限"
    case .recordingFailed(let reason):
      return "录制失败：\(localizedFailureReason(reason))"
    case .microphoneNotFound:
      return "找不到已选择的麦克风"
    case .cameraNotFound:
      return "找不到已选择的摄像头"
    case .cameraStreamFailed:
      return "摄像头无法开始采集。请确认没有其他 App 正在使用摄像头。"
    case .microphoneStreamFailed:
      return "麦克风无法开始采集。请确认没有其他 App 正在使用麦克风。"
    case .deviceNotFound:
      return "未找到 iOS 设备。请用 USB 连接 iPhone 或 iPad，并在设备上信任这台 Mac。"
    case .deviceStreamFailed:
      return "设备无法开始采集。请确认设备已解锁并信任这台 Mac。"
    }
  }

  private func localizedFailureReason(_ reason: String) -> String {
    if reason.hasPrefix("gifski_add_frame failed") {
      return reason.replacingOccurrences(of: "gifski_add_frame failed", with: "添加 GIF 帧失败")
    }
    if reason.hasPrefix("gifski_finish failed") {
      return reason.replacingOccurrences(of: "gifski_finish failed", with: "结束 GIF 编码失败")
    }

    return switch reason {
    case "Failed to create mono audio format": "无法创建单声道音频格式"
    case "No audio data after conversion": "音频转换后没有可用数据"
    case "No output from noise reduction": "降噪没有产生输出"
    case "Failed to allocate output audio buffer": "无法分配输出音频缓冲区"
    case "Failed to allocate stereo audio buffer": "无法分配立体声音频缓冲区"
    case "Failed to allocate audio write buffer": "无法分配音频写入缓冲区"
    case "Unsupported audio format for noise reduction": "当前音频格式不支持降噪"
    case "Failed to allocate audio read buffer": "无法分配音频读取缓冲区"
    case "Failed to allocate audio conversion buffer": "无法分配音频转换缓冲区"
    case "Failed to convert audio to 48kHz mono": "无法将音频转换为 48kHz 单声道"
    case "No video track found": "找不到视频轨道"
    case "No screen track found": "找不到屏幕录制轨道"
    case "No video track in screen recording": "屏幕录制中没有视频轨道"
    case "Failed to create export session": "无法创建导出会话"
    case "Failed to create audio mix session": "无法创建音频混合会话"
    case "Failed to start video reader": "无法启动视频读取器"
    case "Failed to start audio reader": "无法启动音频读取器"
    case "Failed to start writing": "无法开始写入文件"
    case "Failed to create pixel buffer pool": "无法创建像素缓冲池"
    case "Failed to create pixel buffer pool for GIF": "无法为 GIF 创建像素缓冲池"
    case "Export writing failed": "导出写入失败"
    case "Failed to create gifski encoder": "无法创建 GIF 编码器"
    case "Failed to set gifski output file": "无法设置 GIF 输出文件"
    case "Screen recording file missing from project bundle": "项目包中缺少屏幕录制文件"
    default: reason
    }
  }
}
