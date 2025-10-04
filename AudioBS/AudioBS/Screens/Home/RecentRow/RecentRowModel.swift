import API
import Combine
import Models
import SwiftData
import SwiftUI

final class RecentRowModel: RecentRow.Model {
  enum Item {
    case recent(RecentlyPlayedItem)
    case book(Book)
  }

  var item: Item

  private var downloadManager: DownloadManager { .shared }
  private var playerManager: PlayerManager { .shared }
  private var cancellables = Set<AnyCancellable>()
  private var mediaProgressObservation: Task<Void, Never>?
  private var itemObservation: Task<Void, Never>?

  private var onRemoved: (() -> Void)?

  init(recent: RecentlyPlayedItem) {
    self.item = .recent(recent)

    super.init(
      bookID: recent.bookID,
      title: recent.title,
      author: recent.author,
      coverURL: recent.coverURL,
      progress: 0,
      lastPlayedAt: nil,
      timeRemaining: nil,
      downloadState: recent.playSessionInfo.isDownloaded ? .downloaded : .notDownloaded
    )
  }

  init(book: Book, onRemoved: @escaping () -> Void) {
    self.item = .book(book)

    super.init(
      bookID: book.id,
      title: book.title,
      author: book.authorName,
      coverURL: book.coverURL,
      progress: 0,
      lastPlayedAt: nil,
      timeRemaining: nil
    )

    self.onRemoved = onRemoved
  }

  override func onAppear() {
    setupDownloadStateBinding()
    setupProgressObservation()
    setupItemObservation()
  }

  override func onDisappear() {
    mediaProgressObservation?.cancel()
    itemObservation?.cancel()
    cancellables.removeAll()
  }

  override func onTapped() {
    switch item {
    case .recent(let recentItem):
      PlayerManager.shared.setCurrent(recentItem)
    case .book(let book):
      PlayerManager.shared.setCurrent(book)
    }
  }

  private func setupDownloadStateBinding() {
    let bookID = bookID
    Publishers.CombineLatest(downloadManager.$downloads, downloadManager.$downloadProgress)
      .map { [weak self] downloads, progress in
        guard let self = self else { return .notDownloaded }

        if let progress = progress[bookID] {
          return .downloading(progress: progress)
        }

        switch self.item {
        case .recent(let recentItem):
          return recentItem.playSessionInfo.isDownloaded ? .downloaded : .notDownloaded
        case .book:
          return .notDownloaded
        }
      }
      .sink { [weak self] downloadState in
        self?.downloadState = downloadState
      }
      .store(in: &cancellables)
  }

  private func setupItemObservation() {
    let bookID = bookID
    itemObservation = Task { [weak self] in
      for await updatedItem in RecentlyPlayedItem.observe(where: \.bookID, equals: bookID) {
        guard !Task.isCancelled, let self = self else { continue }

        self.item = .recent(updatedItem)

        if let progress = downloadManager.downloadProgress[bookID] {
          self.downloadState = .downloading(progress: progress)
        } else {
          self.downloadState =
            updatedItem.playSessionInfo.isDownloaded ? .downloaded : .notDownloaded
        }
      }
    }
  }

  private func setupProgressObservation() {
    let bookID = bookID
    mediaProgressObservation = Task { [weak self] in
      for await progress in MediaProgress.observe(where: \.bookID, equals: bookID) {
        guard !Task.isCancelled, let self = self else { continue }
        guard !AppStateManager.shared.isInBackground else { continue }

        self.progress = progress.progress
        self.lastPlayedAt = progress.lastPlayedAt

        switch item {
        case .recent:
          self.timeRemaining = Self.formatTimeRemaining(progress: progress)
        case .book(let book):
          self.timeRemaining = Self.formatTimeRemaining(from: book, progress: progress)
        }
      }
    }
  }

  override func onDownloadTapped() {
    switch downloadState {
    case .downloading:
      downloadManager.cancelDownload(for: bookID)
    case .downloaded:
      downloadManager.deleteDownload(for: bookID)
    case .notDownloaded:
      switch item {
      case .recent(let recentItem):
        downloadManager.startDownload(for: recentItem)
      case .book(let book):
        downloadManager.startDownload(for: book)
      }
    }
  }

  override func onDeleteTapped(isFileOnly: Bool) {
    Task {
      do {
        if case .recent(let recent) = item {
          if isFileOnly {
            downloadManager.deleteDownload(for: bookID)
          } else {
            downloadManager.deleteDownload(for: bookID)
            try recent.delete()
          }
        }

        if !isFileOnly, let progress = try? MediaProgress.fetch(bookID: bookID),
          let id = progress.id
        {
          try? await Audiobookshelf.shared.sessions.removeFromContinueListening(id)
          onRemoved?()
        }
      } catch {
        print(error)
      }
    }
  }

  override func onMarkFinishedTapped(isFinished: Bool) {
    Task {
      do {
        try await Audiobookshelf.shared.libraries.updateBookFinishedStatus(
          bookID: bookID, isFinished: isFinished)

        try MediaProgress.updateFinishedStatus(for: bookID, isFinished: isFinished)

        if playerManager.current?.id == bookID {
          playerManager.clearCurrent()
        }
      } catch {
      }
    }
  }

  private static func formatTimeRemaining(progress: MediaProgress) -> String? {
    guard progress.duration > 0 else { return nil }
    let remainingTime = progress.duration - progress.currentTime
    guard remainingTime > 0 else { return nil }
    return Duration.seconds(remainingTime).formatted(
      .units(
        allowed: [.hours, .minutes],
        width: .narrow
      )
    ) + " left"
  }

  private static func formatTimeRemaining(from book: Book, progress: MediaProgress) -> String? {
    guard progress.progress > 0,
      progress.progress < 1.0
    else { return nil }
    let remainingTime = book.duration * (1.0 - progress.progress)
    guard remainingTime > 0 else { return nil }
    return Duration.seconds(remainingTime).formatted(
      .units(
        allowed: [.hours, .minutes],
        width: .narrow
      )
    ) + " left"
  }
}

extension RecentRowModel.Item {
  var id: String {
    switch self {
    case .recent(let recentItem): recentItem.bookID
    case .book(let book): book.id
    }
  }
}
