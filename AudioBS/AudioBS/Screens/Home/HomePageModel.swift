import API
import Models
import SwiftData
import SwiftUI

final class HomePageModel: HomePage.Model {
  private let downloadManager = DownloadManager.shared
  private var playerManager = PlayerManager.shared

  private var recentItemsTask: Task<Void, Never>?

  private var availableOffline: [LocalBook] = []

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
    availableOffline = []
    continueListening = []
    others = []
    recents = nil
    offline = nil
    isLoading = false

    if shouldRefresh {
      onAppear()
    }
  }
}

extension HomePageModel {
  private func setupRecentItemsObservation() {
    recentItemsTask = Task { [weak self] in
      for await recents in LocalBook.observeAll() {
        guard !Task.isCancelled else { break }
        self?.availableOffline = recents
        self?.refreshRecents()
      }
    }
  }

  private func refreshRecents() {
    var recentItems: [RecentRowModel] = []

    for book in continueListening {
      recentItems.append(
        RecentRowModel(
          book: book,
          onRemoved: { [weak self] in
            guard let self else { return }
            self.continueListening = self.continueListening.filter({ $0.id != book.id })
          }
        )
      )
    }

    let sortedRecents = recentItems.sorted(by: >)

    if !sortedRecents.isEmpty {
      self.recents = Section(title: "Continue Listening", items: .recents(sortedRecents))
    } else {
      self.recents = nil
    }

    var offline = [BookCard.Model]()

    for book in availableOffline {
      if [false, nil].contains(downloadManager.downloads[book.bookID]), !book.isDownloaded,
        PlayerManager.shared.current?.id != book.bookID
      {
        try? book.delete()
      } else if book.isDownloaded {
        offline.append(BookCardModel(book))
      }
    }

    if !offline.isEmpty {
      self.offline = Section(title: "Available Offline", items: .books(offline))
    } else {
      self.offline = nil
    }
  }

  private func processSections(_ personalized: [Personalized.Section]) {
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
        let series = items.map { SeriesCardModel(series: $0) }
        sections.append(.init(title: section.label, items: .series(series)))

      case .authors(let items):
        let authors = items.map { AuthorCardModel(author: $0) }
        sections.append(.init(title: section.label, items: .authors(authors)))

      case .unknown:
        continue
      }
    }

    self.others = sections
  }

}

extension HomePageModel {
  private func loadCachedContent() {
    guard let personalized = Audiobookshelf.shared.libraries.getCachedPersonalized() else {
      return
    }

    processSections(personalized.sections)
  }

  private func fetchRemoteContent() async {
    if others.isEmpty {
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
