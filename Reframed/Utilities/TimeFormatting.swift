import AVFoundation

func formatDuration(seconds totalSeconds: Int) -> String {
  let hours = totalSeconds / 3600
  let minutes = (totalSeconds % 3600) / 60
  let seconds = totalSeconds % 60
  if hours > 0 {
    return String(format: "%d:%02d:%02d", hours, minutes, seconds)
  }
  return String(format: "%02d:%02d", minutes, seconds)
}

func formatDuration(_ time: CMTime) -> String {
  let totalSeconds = max(0, Int(CMTimeGetSeconds(time)))
  return formatDuration(seconds: totalSeconds)
}

func formatPreciseDuration(_ time: CMTime) -> String {
  formatPreciseDuration(seconds: max(0, CMTimeGetSeconds(time)))
}

func formatPreciseDuration(seconds raw: Double) -> String {
  let totalSeconds = Int(raw)
  let centiseconds = Int((raw - Double(totalSeconds)) * 100)
  let minutes = totalSeconds / 60
  let seconds = totalSeconds % 60
  return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
}

func formatCompactTime(seconds: Double) -> String {
  let mins = Int(seconds) / 60
  let secs = seconds - Double(mins * 60)
  if mins > 0 {
    return String(format: "%d:%04.1f", mins, secs)
  }
  return String(format: "%.1f秒", secs)
}

func formatTimeRange(start: Double, end: Double) -> String {
  let fmt = { (s: Double) -> String in
    let mins = Int(s) / 60
    let secs = Int(s) % 60
    let frac = Int((s - Double(Int(s))) * 10)
    if mins > 0 {
      return String(format: "%d:%02d.%d", mins, secs, frac)
    }
    return String(format: "%d.%d", secs, frac)
  }
  return "\(fmt(start))–\(fmt(end))"
}

func formatTimestamp(_ date: Date = Date()) -> String {
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM-dd-HHmmss"
  return formatter.string(from: date)
}

func formatRelativeTime(_ date: Date) -> String {
  let seconds = Int(-date.timeIntervalSinceNow)
  if seconds < 5 { return "刚刚" }
  if seconds < 60 { return "\(seconds) 秒前" }
  let minutes = seconds / 60
  if minutes < 60 { return "\(minutes) 分钟前" }
  let hours = minutes / 60
  if hours < 24 { return "\(hours) 小时前" }
  let days = hours / 24
  return "\(days) 天前"
}
