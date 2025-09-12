import Audiobookshelf
import SwiftData
import SwiftUI

@MainActor
final class HomeViewModel: HomeView.Model {
  private var playerManager = PlayerManager.shared
  private var recentItemsTask: Task<Void, Never>?

  private var recentlyPlayed: [RecentlyPlayedItem] = [] {
    didSet { refreshRecents() }
  }

  private var continueListening: [Book] = [] {
    didSet { refreshRecents() }
  }

  init() {
    super.init()
    setupRecentItemsObservation()
  }

  private func setupRecentItemsObservation() {
    recentItemsTask = Task {
      for await recents in RecentlyPlayedItem.observeAll() {
        guard !Task.isCancelled else { break }
        recentlyPlayed = recents
      }
    }
  }

  private func refreshRecents() {
    var recents: [RecentRowModel] = []

    var recentsByID = Dictionary(uniqueKeysWithValues: recentlyPlayed.map { ($0.bookID, $0) })

    for book in continueListening {
      if let recent = recentsByID[book.id] {
        recents.append(RecentRowModel(recent: recent))
        recentsByID.removeValue(forKey: book.id)
      } else {
        recents.append(
          RecentRowModel(
            book: book,
            onRemoved: { [weak self] in
              guard let self else { return }
              self.continueListening = self.continueListening.filter({ $0.id != book.id })
            }
          )
        )
      }
    }

    for recent in recentsByID.values {
      let progress = try? MediaProgress.fetch(bookID: recent.bookID)
      if recent.playSessionInfo.isDownloaded || (progress?.timeListened ?? 0) != 0
        || PlayerManager.shared.current?.id == recent.bookID
      {
        recents.append(RecentRowModel(recent: recent))
      } else {
        try? recent.delete()
      }
    }

    self.recents = recents.sorted { lhs, rhs in
      switch (lhs.lastPlayedAt, rhs.lastPlayedAt) {
      case (.none, .none): false
      case (.some, .none): true
      case (.none, .some): false
      case let (.some(lhs), .some(rhs)): lhs > rhs
      }
    }
  }

  override func onAppear() {
    Task {
      await loadPersonalizedContent()
    }
  }

  override func refresh() async {
    await loadPersonalizedContent()
  }

  private func loadPersonalizedContent() async {
    isLoading = true

    do {
      async let progressSync: Void = MediaProgress.syncFromAPI()
      async let recentSync: Void = syncRecentItemsProgress()

      _ = try await (progressSync, recentSync)

      let personalized = try await Audiobookshelf.shared.libraries.fetchPersonalized()

      var sections = [Section]()
      for section in personalized {
        switch section.entities {
        case .books(let items):
          if section.id == "continue-listening" {
            continueListening = items
            continue
          } else {
            let books = items.map({ BookCardModel($0, sortBy: .title) })
            sections.append(.init(title: section.label, items: .books(books)))
          }

        case .series(let items):
          let series = items.map(SeriesCardModel.init)
          sections.append(.init(title: section.label, items: .series(series)))
        }
      }

      self.sections = sections
    } catch {
      sections = []
    }

    isLoading = false
  }

  private func syncRecentItemsProgress() async {
    do {
      let recentItems = try RecentlyPlayedItem.fetchAll()
      let currentBookID = PlayerManager.shared.current?.id

      for item in recentItems {
        let progress = try? MediaProgress.fetch(bookID: item.bookID)
        guard item.bookID != currentBookID,
          (progress?.timeListened ?? 0) > 0
        else { continue }

        await syncItemProgress(item)
      }
    } catch {
    }
  }

  private func syncItemProgress(_ item: RecentlyPlayedItem) async {
    guard let localProgress = try? MediaProgress.fetch(bookID: item.bookID) else { return }

    if localProgress.timeListened > 0 {
      await syncWithSessionRecreation(item, progress: localProgress)
    } else {
    }
  }

  private func syncWithSessionRecreation(_ item: RecentlyPlayedItem, progress: MediaProgress) async
  {
    do {
      let sessionInfo = item.playSessionInfo

      do {
        try await Audiobookshelf.shared.sessions.sync(
          sessionInfo.id,
          timeListened: progress.timeListened,
          currentTime: progress.currentTime
        )

        try? MediaProgress.updateProgress(
          for: item.bookID,
          currentTime: progress.currentTime,
          timeListened: 0,
          duration: progress.duration,
          progress: progress.progress
        )
      } catch {

        do {
          let newSession = try await Audiobookshelf.shared.sessions.start(
            itemID: item.bookID,
            forceTranscode: false
          )

          let newSessionInfo = PlaySessionInfo(from: newSession)
          item.playSessionInfo.merge(with: newSessionInfo)

          try await Audiobookshelf.shared.sessions.sync(
            newSessionInfo.id,
            timeListened: progress.timeListened,
            currentTime: progress.currentTime
          )

          try? MediaProgress.updateProgress(
            for: item.bookID,
            currentTime: progress.currentTime,
            timeListened: 0,
            duration: progress.duration,
            progress: progress.progress
          )
        } catch {
        }
      }
    }
  }
}
