import API
import Foundation
import Models

final class ContinueListeningRowModel: ContinueListeningRow.Model {
  private let book: Book
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
    fetchProgressData()
  }

  private func fetchProgressData() {
    guard let mediaProgress = try? MediaProgress.fetch(bookID: bookID) else { return }

    progress = mediaProgress.progress

    if let current = PlayerManager.shared.current, current.id == bookID, current.isPlaying {
      lastPlayedAt = .distantFuture
    } else {
      lastPlayedAt = mediaProgress.lastPlayedAt
    }

    timeRemaining = Self.formatTimeRemaining(from: book, progress: mediaProgress)
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
