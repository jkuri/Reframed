import CoreMedia
import Testing

private func seconds(_ value: Double) -> CMTime {
  CMTime(seconds: value, preferredTimescale: 600)
}

@Test func clampKeepsSpeedInsideSupportedRange() {
  #expect(TimeLapse.clamp(1) == 1)
  #expect(TimeLapse.clamp(4) == 4)
  #expect(TimeLapse.clamp(16) == 16)
  #expect(TimeLapse.clamp(0.5) == TimeLapse.range.lowerBound)
  #expect(TimeLapse.clamp(-3) == TimeLapse.range.lowerBound)
  #expect(TimeLapse.clamp(.nan) == TimeLapse.range.lowerBound)
  #expect(TimeLapse.clamp(-.infinity) == TimeLapse.range.lowerBound)
  #expect(TimeLapse.clamp(100) == TimeLapse.range.upperBound)
  #expect(TimeLapse.clamp(.infinity) == TimeLapse.range.upperBound)
}

@Test func frameCountScalesInverselyWithSpeed() {
  let duration = seconds(10)
  #expect(TimeLapse.frameCount(duration: duration, fps: 30, speed: 1) == 300)
  #expect(TimeLapse.frameCount(duration: duration, fps: 30, speed: 2) == 150)
  #expect(TimeLapse.frameCount(duration: duration, fps: 30, speed: 4) == 75)
  #expect(TimeLapse.frameCount(duration: duration, fps: 30, speed: 2.5) == 120)
}

@Test func frameCountRoundsUpOnNonDivisibleSpeeds() {
  #expect(TimeLapse.frameCount(duration: seconds(7), fps: 24, speed: 3) == 56)
  #expect(TimeLapse.frameCount(duration: seconds(10), fps: 30, speed: 16) == 19)
}

@Test func frameCountClampsDegenerateSpeeds() {
  let duration = seconds(10)
  let atNormalSpeed = TimeLapse.frameCount(duration: duration, fps: 30, speed: 1)
  for speed in [0, -1, -0.5, Double.nan] {
    #expect(TimeLapse.frameCount(duration: duration, fps: 30, speed: speed) == atNormalSpeed)
  }
  #expect(TimeLapse.frameCount(duration: duration, fps: 30, speed: -.infinity) == atNormalSpeed)
  #expect(TimeLapse.frameCount(duration: duration, fps: 30, speed: .infinity) == 19)
  #expect(TimeLapse.frameCount(duration: duration, fps: 30, speed: 1000) == 19)
}

@Test func frameCountHandlesZeroAndInvalidDuration() {
  #expect(TimeLapse.frameCount(duration: .zero, fps: 30, speed: 4) == 0)
  #expect(TimeLapse.frameCount(duration: .invalid, fps: 30, speed: 4) == 0)
  #expect(TimeLapse.frameCount(duration: seconds(10), fps: 0, speed: 4) == 0)
}

@Test func sourceTimeIsIdentityAtNormalSpeed() {
  let outputTime = CMTime(value: 45, timescale: 30)
  #expect(CMTimeCompare(TimeLapse.sourceTime(forOutput: outputTime, speed: 1), outputTime) == 0)
  #expect(TimeLapse.sourceTime(forOutput: .zero, speed: 8) == .zero)
}

@Test func sourceTimeAdvancesBySpeedFactor() {
  let outputTime = CMTime(value: 30, timescale: 30)
  let sourceTime = TimeLapse.sourceTime(forOutput: outputTime, speed: 4)
  #expect(abs(CMTimeGetSeconds(sourceTime) - 4.0) < 0.0001)
}

@Test func lastFrameNeverReadsPastSourceDuration() {
  let total = 10.0
  for speed in [1.0, 1.5, 2.0, 4.0, 8.0, 16.0] {
    for fps in [24, 30, 60] {
      let count = TimeLapse.frameCount(duration: seconds(total), fps: fps, speed: speed)
      let lastOutput = CMTime(value: CMTimeValue(count - 1), timescale: CMTimeScale(fps))
      let lastSource = CMTimeGetSeconds(TimeLapse.sourceTime(forOutput: lastOutput, speed: speed))
      #expect(lastSource < total)
    }
  }
}

@Test func effectiveDurationMatchesExportedLength() {
  #expect(abs(TimeLapse.effectiveDuration(seconds: 600, speed: 8) - 75.0) < 0.0001)
  #expect(abs(TimeLapse.effectiveDuration(seconds: 600, speed: 1) - 600.0) < 0.0001)
  #expect(TimeLapse.effectiveDuration(seconds: 0, speed: 4) == 0)
  #expect(TimeLapse.effectiveDuration(seconds: -5, speed: 4) == 0)
  #expect(TimeLapse.effectiveDuration(seconds: .nan, speed: 4) == 0)
}

@Test func audioIsDroppedOnlyAboveNormalSpeed() {
  #expect(TimeLapse.dropsAudio(speed: 1) == false)
  #expect(TimeLapse.dropsAudio(speed: 0.5) == false)
  #expect(TimeLapse.dropsAudio(speed: 1.0001) == true)
  #expect(TimeLapse.dropsAudio(speed: 8) == true)
}
