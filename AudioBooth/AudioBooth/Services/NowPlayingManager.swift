import API
import Foundation
import Logging
import MediaPlayer
import Nuke

final class NowPlayingManager {
  private var info: [String: Any] = [:]
  private let id: String
  private let title: String
  private let author: String?
  private var artwork: MPMediaItemArtwork?
  private let preferences = UserPreferences.shared
  private var playbackState: MPNowPlayingPlaybackState = .paused

  init(
    id: String,
    title: String,
    author: String?,
    coverURL: URL?,
    current: TimeInterval,
    duration: TimeInterval
  ) {
    self.id = id
    self.title = title
    self.author = author

    info[MPNowPlayingInfoPropertyExternalContentIdentifier] = id
    info[MPNowPlayingInfoPropertyExternalUserProfileIdentifier] = Audiobookshelf.shared.authentication.server?.id

    info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
    info[MPMediaItemPropertyTitle] = title
    info[MPMediaItemPropertyArtist] = author

    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = current
    info[MPMediaItemPropertyPlaybackDuration] = duration

    info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
    info[MPNowPlayingInfoPropertyPlaybackRate] = 0.0

    update()

    if let coverURL {
      loadArtwork(from: coverURL)
    }

    Self.primeNowPlaying()
  }

  private static func primeNowPlaying() {
    Task {
      do {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .spokenAudio)
        try audioSession.setActive(true)

        let url = URL(string: "data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQAAAAA=")!
        let player = AVPlayer(url: url)
        player.volume = 0
        player.play()
        try? await Task.sleep(for: .milliseconds(100))
        player.pause()
      } catch {
        AppLogger.player.debug("Failed to prime Now Playing: \(error)")
      }
    }
  }

  func update(chapter: String, current: TimeInterval, duration: TimeInterval) {
    info[MPMediaItemPropertyArtwork] = artwork

    if preferences.showFullBookDuration {
      update(current: current)
      return
    }

    info[MPMediaItemPropertyTitle] = chapter
    info[MPMediaItemPropertyArtist] = title
    info[MPMediaItemPropertyPlaybackDuration] = duration
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = current

    update()
  }

  func update(current: TimeInterval) {
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = current

    update()
  }

  func update(speed: Float) {
    info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = Double(speed)

    update()
  }

  func update(rate: Float, current: TimeInterval) {
    info[MPNowPlayingInfoPropertyPlaybackRate] = Double(rate)
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = current
    playbackState = rate > 0 ? .playing : .paused

    update()
  }

  func clear() {
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
  }

  func update() {
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    MPNowPlayingInfoCenter.default().playbackState = playbackState
  }

  private func loadArtwork(from url: URL) {
    Task {
      do {
        let request = ImageRequest(url: url)
        let image = try await ImagePipeline.shared.image(for: request)

        artwork = MPMediaItemArtwork(
          boundsSize: image.size,
          requestHandler: { _ in image }
        )

        info[MPMediaItemPropertyArtwork] = artwork
        update()
      } catch {
        AppLogger.player.error("Failed to load cover image for now playing: \(error)")
      }
    }
  }
}
