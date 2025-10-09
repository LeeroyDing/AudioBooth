import API
import Combine
import Models
import SwiftData
import SwiftUI

final class RecentRowModel: RecentRow.Model {
  private let book: Book

  private var downloadManager: DownloadManager { .shared }
  private var playerManager: PlayerManager { .shared }
  private var cancellables = Set<AnyCancellable>()
  private var mediaProgressObservation: Task<Void, Never>?
  private var localBookObservation: Task<Void, Never>?

  private var onRemoved: (() -> Void)?

  init(book: Book, onRemoved: @escaping () -> Void) {
    self.book = book

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
    setupLocalBookObservation()
  }

  override func onDisappear() {
    mediaProgressObservation?.cancel()
    localBookObservation?.cancel()
    cancellables.removeAll()
  }

  private func setupDownloadStateBinding() {
    let bookID = bookID
    downloadManager.$downloadProgress
      .map { progress -> DownloadManager.DownloadState? in
        if let downloadProgress = progress[bookID] {
          return .downloading(progress: downloadProgress)
        }
        return nil
      }
      .sink { [weak self] downloadState in
        if let downloadState = downloadState {
          self?.downloadState = downloadState
          print(downloadState)
        } else {
          self?.downloadState = .notDownloaded
        }
      }
      .store(in: &cancellables)
  }

  private func setupLocalBookObservation() {
    let bookID = bookID
    localBookObservation = Task { [weak self] in
      for await localBook in LocalBook.observe(where: \.bookID, equals: bookID) {
        guard !Task.isCancelled, let self = self else { continue }

        if let progress = downloadManager.downloadProgress[bookID] {
          self.downloadState = .downloading(progress: progress)
        } else if localBook.isDownloaded {
          self.downloadState = .downloaded
        } else {
          self.downloadState = .notDownloaded
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
        self.timeRemaining = Self.formatTimeRemaining(from: self.book, progress: progress)
      }
    }
  }

  override func onDownloadTapped() {
    downloadManager.startDownload(for: bookID)
    downloadState = .downloading(progress: 0)
  }

  override func onCancelDownloadTapped() {
    downloadManager.cancelDownload(for: bookID)
    downloadState = .notDownloaded
  }

  override func onRemoveFromDeviceTapped() {
    downloadManager.deleteDownload(for: bookID)

    if let localBook = try? LocalBook.fetch(bookID: bookID) {
      try? localBook.delete()
    }

    downloadState = .notDownloaded

  }

  override func onRemoveFromListTapped() {
    guard
      let progress = try? MediaProgress.fetch(bookID: bookID),
      let id = progress.id
    else { return }

    Task {
      try? await Audiobookshelf.shared.sessions.removeFromContinueListening(id)
      onRemoved?()
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
