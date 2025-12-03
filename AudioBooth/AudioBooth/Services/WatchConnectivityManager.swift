import API
import Combine
import Foundation
import Logging
import Models
import WatchConnectivity

final class WatchConnectivityManager: NSObject, ObservableObject {
  static let shared = WatchConnectivityManager()

  private var session: WCSession?
  private var cancellables = Set<AnyCancellable>()

  private override init() {
    super.init()

    if WCSession.isSupported() {
      session = WCSession.default
      session?.delegate = self
      session?.activate()
    }
  }

  func sendPlaybackState(
    isPlaying: Bool,
    progress: Double,
    current: Double,
    remaining: Double,
    total: Double,
    totalTimeRemaining: Double,
    bookID: String,
    title: String,
    author: String?,
    coverURL: URL?,
    playbackSpeed: Float
  ) {
    guard let session = session else { return }

    var context = session.applicationContext

    context["isPlaying"] = isPlaying
    context["progress"] = progress
    context["current"] = current
    context["remaining"] = remaining
    context["total"] = total
    context["totalTimeRemaining"] = totalTimeRemaining
    context["bookID"] = bookID
    context["title"] = title
    context["author"] = author
    context["coverURL"] = watchCompatibleCoverURL(from: coverURL)
    context["playbackSpeed"] = playbackSpeed
    context["hasActivePlayer"] = true

    do {
      try session.updateApplicationContext(context)
    } catch {
      AppLogger.watchConnectivity.error(
        "Failed to send playback state to watch: \(error)")
    }
  }

  private func watchCompatibleCoverURL(from url: URL?) -> String? {
    guard let url = url else { return nil }

    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    components?.queryItems = [URLQueryItem(name: "format", value: "jpg")]
    return components?.url?.absoluteString ?? url.absoluteString
  }

  func clearPlaybackState() {
    guard let session = session, session.isReachable else { return }

    var context = session.applicationContext
    context["hasActivePlayer"] = false
    context.removeValue(forKey: "isPlaying")
    context.removeValue(forKey: "progress")
    context.removeValue(forKey: "current")
    context.removeValue(forKey: "remaining")
    context.removeValue(forKey: "total")
    context.removeValue(forKey: "totalTimeRemaining")
    context.removeValue(forKey: "bookID")
    context.removeValue(forKey: "title")
    context.removeValue(forKey: "author")
    context.removeValue(forKey: "coverURL")
    context.removeValue(forKey: "playbackSpeed")

    do {
      try session.updateApplicationContext(context)
    } catch {
      AppLogger.watchConnectivity.error(
        "Failed to clear playback state on watch: \(error)")
    }
  }

  func syncAuthCredentials(serverURL: URL, token: String) {
    guard let session = session else { return }

    var context = session.applicationContext
    context["authServerURL"] = serverURL.absoluteString
    context["authToken"] = token

    do {
      try session.updateApplicationContext(context)
      AppLogger.watchConnectivity.info("Synced auth credentials to watch")
    } catch {
      AppLogger.watchConnectivity.error(
        "Failed to sync auth credentials to watch: \(error)")
    }
  }

  func clearAuthCredentials() {
    guard let session = session else { return }

    var context = session.applicationContext
    context.removeValue(forKey: "authServerURL")
    context.removeValue(forKey: "authToken")

    do {
      try session.updateApplicationContext(context)
      AppLogger.watchConnectivity.info("Cleared auth credentials on watch")
    } catch {
      AppLogger.watchConnectivity.error(
        "Failed to clear auth credentials on watch: \(error)")
    }
  }

  func syncLibrary(_ library: Library) {
    guard let session = session else { return }

    var context = session.applicationContext
    if let libraryData = try? JSONEncoder().encode(library) {
      context["library"] = libraryData
      do {
        try session.updateApplicationContext(context)
        AppLogger.watchConnectivity.info(
          "Synced library to watch: \(library.name)")
      } catch {
        AppLogger.watchConnectivity.error(
          "Failed to sync library to watch: \(error)")
      }
    }
  }

  func clearLibrary() {
    guard let session = session else { return }

    var context = session.applicationContext
    context.removeValue(forKey: "library")

    do {
      try session.updateApplicationContext(context)
      AppLogger.watchConnectivity.info("Cleared library on watch")
    } catch {
      AppLogger.watchConnectivity.error(
        "Failed to clear library on watch: \(error)")
    }
  }

}

extension WatchConnectivityManager: WCSessionDelegate {
  func session(
    _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    if let error = error {
      AppLogger.watchConnectivity.error(
        "Watch session activation failed: \(error)")
    } else {
      AppLogger.watchConnectivity.info(
        "Watch session activated with state: \(activationState.rawValue)")
    }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {
    AppLogger.watchConnectivity.info("Watch session became inactive")
  }

  func sessionDidDeactivate(_ session: WCSession) {
    AppLogger.watchConnectivity.info("Watch session deactivated, reactivating...")
    session.activate()
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    AppLogger.watchConnectivity.debug("Received message from watch: \(message)")

    guard let command = message["command"] as? String else { return }

    Task { @MainActor in
      switch command {
      case "play":
        if let bookID = message["bookID"] as? String {
          handlePlayCommand(bookID: bookID)
        } else {
          updatePlaybackStateContext(isPlaying: true)
          PlayerManager.shared.current?.onPlayTapped()
        }
      case "pause":
        updatePlaybackStateContext(isPlaying: false)
        PlayerManager.shared.current?.onPauseTapped()
      case "skipForward":
        let interval = UserDefaults.standard.double(forKey: "skipForwardInterval")
        PlayerManager.shared.current?.onSkipForwardTapped(seconds: interval)
      case "skipBackward":
        let interval = UserDefaults.standard.double(forKey: "skipBackwardInterval")
        PlayerManager.shared.current?.onSkipBackwardTapped(seconds: interval)
      case "requestContext":
        handleRequestContext()
      default:
        AppLogger.watchConnectivity.warning(
          "Unknown command from watch: \(command)")
      }
    }
  }

  private func handleRequestContext() {
    guard let session = session else { return }

    AppLogger.watchConnectivity.info("Watch requested full context, sending auth and library")

    var context = session.applicationContext

    if let server = Audiobookshelf.shared.authentication.server {
      context["authServerURL"] = server.baseURL.absoluteString
      context["authToken"] = server.token
    }

    if let library = Audiobookshelf.shared.libraries.current,
      let libraryData = try? JSONEncoder().encode(library)
    {
      context["library"] = libraryData
    }

    do {
      try session.updateApplicationContext(context)
      AppLogger.watchConnectivity.info("Sent full context to watch")
    } catch {
      AppLogger.watchConnectivity.error(
        "Failed to send full context to watch: \(error)")
    }
  }

  private func updatePlaybackStateContext(isPlaying: Bool) {
    guard let session = session else { return }

    var context = session.applicationContext
    context["isPlaying"] = isPlaying

    do {
      try session.updateApplicationContext(context)
    } catch {
      AppLogger.watchConnectivity.error(
        "Failed to update playback state context: \(error)")
    }
  }

  private func handlePlayCommand(bookID: String) {
    Task { @MainActor in
      do {
        if let book = try LocalBook.fetch(bookID: bookID) {
          PlayerManager.shared.setCurrent(book)
          PlayerManager.shared.current?.onPlayTapped()
          PlayerManager.shared.showFullPlayer()
        } else {
          AppLogger.watchConnectivity.info("Book not found locally, fetching from server...")
          let session = try await Audiobookshelf.shared.sessions.start(
            itemID: bookID,
            forceTranscode: false
          )

          PlayerManager.shared.setCurrent(session.libraryItem)
          PlayerManager.shared.current?.onPlayTapped()
          PlayerManager.shared.showFullPlayer()
        }
      } catch {
        AppLogger.watchConnectivity.error(
          "Failed to handle play command: \(error)")
      }
    }
  }
}
