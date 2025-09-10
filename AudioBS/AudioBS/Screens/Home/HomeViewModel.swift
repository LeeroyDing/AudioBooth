import Audiobookshelf
import SwiftData
import SwiftUI

@MainActor
final class HomeViewModel: HomeView.Model {
  private var playerManager = PlayerManager.shared
  private var userProgressService = UserProgressService.shared
  private var recentItemsTask: Task<Void, Never>?

  init() {
    super.init()
    setupRecentItemsObservation()
  }

  private func setupRecentItemsObservation() {
    recentItemsTask = Task {
      for await recents in RecentlyPlayedItem.observeAll() {
        guard !Task.isCancelled else { break }

        for recent in recents {
          if let index = self.recents.firstIndex(where: { $0.id == recent.bookID }) {
            self.recents[index] = RecentRowModel(recent: recent)
          } else {
            self.recents.insert(RecentRowModel(recent: recent), at: 0)
          }
        }
      }
    }
  }

  private func updateRecentsWithContinueListening(
    _ serverBooks: [Book], localItems: [RecentlyPlayedItem]
  ) async {
    var recents: [RecentRowModel] = []

    var recentsByID = Dictionary(uniqueKeysWithValues: localItems.map { ($0.bookID, $0) })

    for book in serverBooks {
      if let recent = recentsByID[book.id] {
        recents.append(RecentRowModel(recent: recent))
        recentsByID.removeValue(forKey: book.id)
      } else {
        let progress = userProgressService.progressByBookID[book.id]
        recents.append(
          RecentRowModel(
            book: book,
            progress: progress?.progress,
            lastPlayedAt: progress.map {
              Date(timeIntervalSince1970: TimeInterval($0.lastUpdate / 1000))
            }
          )
        )
      }
    }

    for recent in recentsByID.values {
      if recent.playSessionInfo.hasLocalFiles || recent.timeListened != 0
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
      async let personalizedTask = Audiobookshelf.shared.libraries.fetchPersonalized()
      async let userProgressTask = userProgressService.refresh()

      let (personalized, _) = try await (personalizedTask, userProgressTask)

      var sections = [Section]()
      for section in personalized {
        switch section.entities {
        case .books(let items):
          if section.id == "continue-listening" {
            let localItems = try RecentlyPlayedItem.fetchAll()
            await updateRecentsWithContinueListening(items, localItems: localItems)

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
      print("Failed to fetch personalized content: \(error)")
      sections = []
    }

    isLoading = false
  }

  override func onDelete(_ model: RecentRow.Model) {
    Task {
      do {
        if let recentItem = try RecentlyPlayedItem.fetch(bookID: model.id) {
          try recentItem.delete()
        }

        if let progress = userProgressService.progressByBookID[model.id] {
          try? await Audiobookshelf.shared.sessions.removeFromContinueListening(progress.id)
        }

        recents.removeAll { $0.id == model.id }
      } catch {
        print("Failed to delete item: \(error)")
      }
    }
  }
}
