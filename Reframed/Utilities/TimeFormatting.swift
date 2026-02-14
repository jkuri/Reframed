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
  let raw = max(0, CMTimeGetSeconds(time))
  let totalSeconds = Int(raw)
  let centiseconds = Int((raw - Double(totalSeconds)) * 100)
  let minutes = totalSeconds / 60
  let seconds = totalSeconds % 60
  return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
}
