import AVFoundation
import SwiftUI

@MainActor
final class PlaybackProgressViewModel: PlaybackProgressView.Model {
  private var player: AVPlayer?
  private var chapters: ChapterPickerSheet.Model?
  private var totalDuration: TimeInterval?
  private var currentTime: TimeInterval = 0
  private var isPlayerLoading: Bool = false

  override init(
    progress: CGFloat = 0,
    current: TimeInterval = 0,
    remaining: TimeInterval = 0,
    total: TimeInterval = 0,
    totalTimeRemaining: TimeInterval = 0,
    isLoading: Bool = false
  ) {
    super.init(
      progress: progress,
      current: current,
      remaining: remaining,
      total: total,
      totalTimeRemaining: totalTimeRemaining,
      isLoading: isLoading
    )
  }

  func configure(
    player: AVPlayer?, chapters: ChapterPickerSheet.Model?, totalDuration: TimeInterval?
  ) {
    self.player = player
    self.chapters = chapters
    self.totalDuration = totalDuration
    updateProgress()
  }

  func updateCurrentTime(_ time: TimeInterval) {
    self.currentTime = time
    updateProgress()
  }

  func updateLoadingState(_ isLoading: Bool) {
    self.isPlayerLoading = isLoading
    self.isLoading = isLoading
  }

  private func updateProgress() {
    guard let totalDuration = totalDuration else {
      progress = 0
      current = 0
      remaining = 0
      total = 0
      totalTimeRemaining = 0
      return
    }

    let currentTime = self.currentTime
    let current: TimeInterval
    let remaining: TimeInterval
    let progress: CGFloat

    if let chapters = chapters, chapters.current != nil {
      current = chapters.currentElapsedTime(currentTime: currentTime)
      remaining = chapters.currentRemainingTime(currentTime: currentTime)
      progress = CGFloat(chapters.currentProgress(currentTime: currentTime))
    } else {
      current = currentTime
      remaining = totalDuration - currentTime
      progress = CGFloat(currentTime / totalDuration)
    }

    self.progress = progress
    self.current = current
    self.remaining = remaining
    self.total = totalDuration
    self.totalTimeRemaining = totalDuration - currentTime
    self.isLoading = isPlayerLoading
  }

  override func onProgressChanged(_ progress: Double) {
    guard let player = player else { return }

    if let chapter = chapters?.current {
      let duration = chapter.end - chapter.start
      let seekTime = chapter.start + (duration * progress)
      player.seek(to: CMTime(seconds: seekTime, preferredTimescale: 1000))
    } else if let totalDuration = totalDuration {
      let seekTime = totalDuration * progress
      player.seek(to: CMTime(seconds: seekTime, preferredTimescale: 1000))
    }
  }
}
