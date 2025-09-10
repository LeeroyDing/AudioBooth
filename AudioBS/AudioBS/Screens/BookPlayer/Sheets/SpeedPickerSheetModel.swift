import AVFoundation
import SwiftUI

@MainActor
final class SpeedPickerSheetViewModel: SpeedPickerSheet.Model {
  let player: AVPlayer

  init(player: AVPlayer) {
    self.player = player
    super.init()
  }

  override func onSpeedIncrease() {
    let newSpeed = min(playbackSpeed + 0.05, 3.5)
    onSpeedChanged(newSpeed)
  }

  override func onSpeedDecrease() {
    let newSpeed = max(playbackSpeed - 0.05, 0.5)
    onSpeedChanged(newSpeed)
  }

  override func onSpeedChanged(_ speed: Float) {
    let roundedSpeed = round(speed / 0.05) * 0.05
    playbackSpeed = roundedSpeed
    player.rate = roundedSpeed
  }
}
