import Combine
import Foundation

final class RemotePlayerModel: PlayerView.Model {
  private var cancellables = Set<AnyCancellable>()
  private let connectivityManager = WatchConnectivityManager.shared

  init() {
    super.init(isReadyToPlay: true, isLocal: false)
    setupBindings()

    downloadState = .downloaded
  }

  private func setupBindings() {
    connectivityManager.$isPlaying
      .assign(to: \.isPlaying, on: self)
      .store(in: &cancellables)

    connectivityManager.$progress
      .assign(to: \.progress, on: self)
      .store(in: &cancellables)

    connectivityManager.$current
      .assign(to: \.current, on: self)
      .store(in: &cancellables)

    connectivityManager.$remaining
      .assign(to: \.remaining, on: self)
      .store(in: &cancellables)

    connectivityManager.$totalTimeRemaining
      .assign(to: \.totalTimeRemaining, on: self)
      .store(in: &cancellables)

    connectivityManager.$title
      .assign(to: \.title, on: self)
      .store(in: &cancellables)

    connectivityManager.$author
      .assign(to: \.author, on: self)
      .store(in: &cancellables)

    connectivityManager.$coverURL
      .assign(to: \.coverURL, on: self)
      .store(in: &cancellables)
  }

  override func togglePlayback() {
    connectivityManager.togglePlayback()
  }

  override func skipBackward() {
    connectivityManager.skipBackward()
  }

  override func skipForward() {
    connectivityManager.skipForward()
  }
}
