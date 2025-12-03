import API
import Foundation

final class ContentViewModel: ContentView.Model {
  private let connectivityManager = WatchConnectivityManager.shared
  private let audiobookshelf = Audiobookshelf.shared

  override func onAuthenticationWait() async {
    try? await Task.sleep(for: .seconds(15))

    if audiobookshelf.authentication.server == nil || audiobookshelf.libraries.current == nil {
      authTimeout = true
    }
  }

  override func retryAuth() {
    authTimeout = false
    connectivityManager.requestFullContext()

    Task {
      await onAuthenticationWait()
    }
  }
}
