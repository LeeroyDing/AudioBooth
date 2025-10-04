import API
import Combine
import Foundation
import Models

final class PlayerManager: ObservableObject {
  @Published var current: LocalPlayerModel?
  @Published var isShowingFullPlayer = false

  static let shared = PlayerManager()

  private static let currentBookIDKey = "currentBookID"

  private init() {
    Task { @MainActor in
      await self.restoreLastPlayer()
    }
  }

  private func restoreLastPlayer() async {
    guard current == nil,
      let savedBookID = UserDefaults.standard.string(forKey: Self.currentBookIDKey),
      let recent = try? RecentlyPlayedItem.fetch(bookID: savedBookID)
    else {
      return
    }

    setCurrent(recent)
  }

  var hasActivePlayer: Bool {
    current != nil
  }

  var isPlaying: Bool {
    current?.isPlaying ?? false
  }

  func setCurrent(_ item: RecentlyPlayedItem) {
    if item.bookID == current?.item.bookID {
      return
    } else {
      if let currentPlayer = current {
        currentPlayer.closeSession()
      }
      current = LocalPlayerModel(item)
      UserDefaults.standard.set(item.bookID, forKey: Self.currentBookIDKey)
    }
  }

  func clearCurrent() {
    if let currentPlayer = current {
      currentPlayer.closeSession()
    }
    current = nil
    UserDefaults.standard.removeObject(forKey: Self.currentBookIDKey)
  }
}
