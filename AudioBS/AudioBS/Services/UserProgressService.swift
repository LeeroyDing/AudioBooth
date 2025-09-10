import Audiobookshelf
import Combine
import SwiftUI

@MainActor
final class UserProgressService: ObservableObject {
  static let shared = UserProgressService()

  @Published private(set) var progressByBookID: [String: User.MediaProgress] = [:]
  @Published private(set) var lastUpdated: Date?

  private let audiobookshelf = Audiobookshelf.shared
  private var refreshTask: Task<Void, Never>?

  private init() {}

  @discardableResult
  func refresh() async -> Bool {
    refreshTask?.cancel()

    refreshTask = Task {
      guard !Task.isCancelled else { return }

      do {
        let userData = try await audiobookshelf.authentication.fetchMe()

        guard !Task.isCancelled else { return }

        progressByBookID = Dictionary(
          uniqueKeysWithValues: userData.mediaProgress.map { ($0.libraryItemId, $0) }
        )
        lastUpdated = Date()

      } catch {
        print("Failed to fetch user progress: \(error)")
      }
    }

    await refreshTask?.value
    return !progressByBookID.isEmpty
  }

  func refreshIfNeeded() async {
    let shouldRefresh = lastUpdated == nil || Date().timeIntervalSince(lastUpdated!) > 300

    if shouldRefresh {
      await refresh()
    }
  }

  func clearCache() {
    refreshTask?.cancel()
    progressByBookID.removeAll()
    lastUpdated = nil
  }
}
