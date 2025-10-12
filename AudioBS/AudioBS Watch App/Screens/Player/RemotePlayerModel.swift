import Combine
import Foundation

final class RemotePlayerModel: PlayerView.Model {
  private var cancellables = Set<AnyCancellable>()
  private let connectivityManager = WatchConnectivityManager.shared
  private var pendingState: Bool?

  init() {
    super.init(isReadyToPlay: true, isLocal: false)
    setupBindings()
  }

  private func setupBindings() {
    connectivityManager.$isPlaying
      .sink { [weak self] isPlaying in
        guard let self else { return }

        if let pending = self.pendingState, pending == isPlaying {
          self.pendingState = nil
        }

        if self.pendingState == nil {
          self.isPlaying = isPlaying
        }
      }
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
    if isPlaying {
      connectivityManager.pause()
      pendingState = false
    } else {
      connectivityManager.play()
      pendingState = true
    }
    isPlaying.toggle()
  }

  override func skipBackward() {
    connectivityManager.skipBackward()
  }

  override func skipForward() {
    connectivityManager.skipForward()
  }
}
