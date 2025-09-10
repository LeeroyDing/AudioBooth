import AVFoundation
import Foundation
import SwiftUI

@MainActor
final class TimerPickerSheetViewModel: TimerPickerSheet.Model {
  private weak var player: AVPlayer?
  private var sleepTimer: Timer?
  private var timerStartTime: Date?
  private var originalTimerDuration: TimeInterval = 0

  func setPlayer(_ player: AVPlayer?) {
    self.player = player
  }

  override var isPresented: Bool {
    didSet {
      if isPresented && !oldValue {
        selected = current
      }
    }
  }

  override func onQuickTimerSelected(_ minutes: Int) {
    let duration = TimeInterval(minutes * 60)
    selected = .preset(duration)
    onStartTimerTapped()
  }

  override func onChaptersChanged(_ value: Int) {
    selected = .chapters(value)
    if value == 1 {
      onStartTimerTapped()
    }
  }

  override func onOffSelected() {
    selected = .none
    current = .none
    stopSleepTimer()
    isPresented = false
  }

  override func onStartTimerTapped() {
    current = selected
    switch selected {
    case .preset(let duration):
      startSleepTimer(duration: duration)
    case .custom(let duration):
      startSleepTimer(duration: duration)
    case .chapters:
      break
    case .none:
      break
    }
    isPresented = false
    player?.play()
  }

  private func startSleepTimer(duration: TimeInterval) {
    stopSleepTimer()
    timerStartTime = Date()
    originalTimerDuration = duration

    sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      guard let self else { return }
      Task { @MainActor in
        self.updateSleepTimer()
      }
    }

    RunLoop.current.add(sleepTimer!, forMode: .common)
  }

  private func stopSleepTimer() {
    sleepTimer?.invalidate()
    sleepTimer = nil
    timerStartTime = nil
    originalTimerDuration = 0
  }

  private func updateSleepTimer() {
    switch current {
    case .preset(let seconds):
      if seconds > 1 {
        current = .preset(seconds - 1)
      } else {
        pauseFromTimer()
      }

    case .custom(let seconds):
      if seconds > 1 {
        current = .custom(seconds - 1)
      } else {
        pauseFromTimer()
      }

    case .none, .chapters:
      stopSleepTimer()
    }
  }

  private func pauseFromTimer() {
    player?.pause()
    current = .none
    stopSleepTimer()
    print("Timer expired - playback paused")
  }

}
