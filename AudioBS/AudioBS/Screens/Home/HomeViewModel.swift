import API
import Models
import SwiftData
import SwiftUI

final class HomeViewModel: HomeView.Model {
  private let downloadManager = DownloadManager.shared
  private var playerManager = PlayerManager.shared

  private var recentItemsTask: Task<Void, Never>?

  private var recentlyPlayed: [LocalBook] = []

  private var continueListening: [Book] = [] {
    didSet { refreshRecents() }
  }

  init() {
    super.init()
    setupRecentItemsObservation()
    loadCachedContent()
  }

  override func onAppear() {
    Task {
      await fetchRemoteContent()
    }
  }

  override func refresh() async {
    await fetchRemoteContent()
  }

  override func onReset(_ shouldRefresh: Bool) {
    recentlyPlayed = []
    continueListening = []
    sections = []
    recents = []
    isLoading = false

    if shouldRefresh {
      onAppear()
    }
  }
}

extension HomeViewModel {
  private func setupRecentItemsObservation() {
    recentItemsTask = Task { [weak self] in
      for await recents in LocalBook.observeAll() {
        guard !Task.isCancelled else { break }
        self?.recentlyPlayed = recents
        self?.syncRecents()
      }
    }
  }

  private func syncRecents() {
    let ids = Set(recentlyPlayed.map(\.bookID) + continueListening.map(\.id))

    recents.removeAll { recent in !ids.contains(recent.bookID) }

    let existingIDs = Set(recents.map(\.bookID))
    for recent in recentlyPlayed where !existingIDs.contains(recent.bookID) {
      recents.append(RecentRowModel(recent: recent))
    }

    recents.sort(by: >)
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
      if downloadManager.downloads[recent.bookID] == true
        || recent.isDownloaded
        || PlayerManager.shared.current?.id == recent.bookID
      {
        recents.append(RecentRowModel(recent: recent))
      } else {
        try? recent.delete()
      }
    }

    self.recents = recents.sorted(by: >)
  }

  private func processSections(_ personalizedSections: [Personalized.Section]) {
    var sections = [Section]()

    for section in personalizedSections {
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
        let series = items.map { SeriesCardModel(series: $0) }
        sections.append(.init(title: section.label, items: .series(series)))

      case .authors(let items):
        let authors = items.map { AuthorCardModel(author: $0) }
        sections.append(.init(title: section.label, items: .authors(authors)))

      case .unknown:
        continue
      }
    }

    self.sections = sections
  }

}

extension HomeViewModel {
  private func loadCachedContent() {
    guard let personalized = Audiobookshelf.shared.libraries.getCachedPersonalized() else {
      return
    }

    processSections(personalized.sections)
  }

  private func fetchRemoteContent() async {
    if sections.isEmpty {
      isLoading = true
    }

    do {
      try await MediaProgress.syncFromAPI()

      let personalized = try await Audiobookshelf.shared.libraries.fetchPersonalized()
      processSections(personalized.sections)
    } catch {
      print("Failed to fetch personalized content: \(error)")
    }

    isLoading = false
  }
}
