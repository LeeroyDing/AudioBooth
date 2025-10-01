import Combine
import Foundation
import WatchConnectivity

final class WatchConnectivityManager: NSObject, ObservableObject {
  static let shared = WatchConnectivityManager()

  @Published var isPlaying: Bool = false
  @Published var progress: Double = 0
  @Published var current: Double = 0
  @Published var remaining: Double = 0
  @Published var total: Double = 0
  @Published var totalTimeRemaining: Double = 0
  @Published var bookID: String = ""
  @Published var title: String = ""
  @Published var author: String = ""
  @Published var coverURL: URL?
  @Published var playbackSpeed: Float = 1.0
  @Published var hasActivePlayer: Bool = false
  @Published var recentlyPlayed: [RecentlyPlayedItemInfo] = []

  private var session: WCSession?

  private override init() {
    super.init()

    if WCSession.isSupported() {
      session = WCSession.default
      session?.delegate = self
      session?.activate()
    }
  }

  func sendCommand(_ command: String) {
    guard let session = session, session.isReachable else {
      print("Cannot send command - session not reachable")
      return
    }

    let message = ["command": command]
    session.sendMessage(message, replyHandler: nil) { error in
      print("Failed to send command to iOS: \(error)")
    }
  }

  func togglePlayback() {
    sendCommand("togglePlayback")
  }

  func skipForward() {
    sendCommand("skipForward")
  }

  func skipBackward() {
    sendCommand("skipBackward")
  }

  func playBook(bookID: String) {
    guard let session = session, session.isReachable else {
      print("Cannot send play command - session not reachable")
      return
    }

    let message: [String: Any] = [
      "command": "play",
      "bookID": bookID,
    ]

    session.sendMessage(message, replyHandler: nil) { error in
      print("Failed to send play command to iOS: \(error)")
    }
  }
}

extension WatchConnectivityManager: WCSessionDelegate {
  func session(
    _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    if let error = error {
      print("Watch session activation failed: \(error)")
    } else {
      print("Watch session activated with state: \(activationState.rawValue)")
    }
  }

  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any])
  {
    DispatchQueue.main.async {
      if let hasActivePlayer = applicationContext["hasActivePlayer"] as? Bool,
        !hasActivePlayer
      {
        self.hasActivePlayer = false
        return
      }

      if let isPlaying = applicationContext["isPlaying"] as? Bool {
        self.isPlaying = isPlaying
      }

      if let progress = applicationContext["progress"] as? Double {
        self.progress = progress
      }

      if let current = applicationContext["current"] as? Double {
        self.current = current
      }

      if let remaining = applicationContext["remaining"] as? Double {
        self.remaining = remaining
      }

      if let total = applicationContext["total"] as? Double {
        self.total = total
      }

      if let totalTimeRemaining = applicationContext["totalTimeRemaining"] as? Double {
        self.totalTimeRemaining = totalTimeRemaining
      }

      if let bookID = applicationContext["bookID"] as? String {
        self.bookID = bookID
      }

      if let title = applicationContext["title"] as? String {
        self.title = title
      }

      if let author = applicationContext["author"] as? String {
        self.author = author
      }

      if let coverURLString = applicationContext["coverURL"] as? String,
        !coverURLString.isEmpty
      {
        self.coverURL = URL(string: coverURLString)
      } else {
        self.coverURL = nil
      }

      if let playbackSpeed = applicationContext["playbackSpeed"] as? Float {
        self.playbackSpeed = playbackSpeed
      }

      if let recentlyPlayedData = applicationContext["recentlyPlayedData"] as? Data {
        do {
          let decoder = PropertyListDecoder()
          self.recentlyPlayed = try decoder.decode(
            [RecentlyPlayedItemInfo].self, from: recentlyPlayedData)
        } catch {
          print("Failed to decode recently played list: \(error)")
        }
      }

      self.hasActivePlayer = true
    }
  }
}
