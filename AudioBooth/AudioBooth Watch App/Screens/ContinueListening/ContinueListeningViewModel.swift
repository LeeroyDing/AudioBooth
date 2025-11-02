import API
import Combine
import Foundation
import Models
import OSLog
import WatchConnectivity

final class ContinueListeningViewModel: ContinueListeningView.Model {
  private var connectivityManager: WatchConnectivityManager { .shared }
  private var playerManager: PlayerManager { .shared }
  private var cancellables = Set<AnyCancellable>()

  override init(books: [BookItem] = [], isLoading: Bool = false) {
    super.init(books: books, isLoading: isLoading)
    loadCachedBooks()
    observeChanges()
  }

  private func observeChanges() {
    Task { @MainActor in
      for await books in LocalBook.observeAll() {
        updateBooks(from: books)
      }
    }
  }

  private func loadCachedBooks() {
    do {
      let books = try LocalBook.fetchAll()
      updateBooks(from: books)
    } catch {
      AppLogger.viewModel.error("Failed to load cached books: \(error)")
    }
  }

  private func updateBooks(from books: [LocalBook]) {
    let items = books.compactMap { book -> BookItem? in
      guard let mediaProgress = try? MediaProgress.getOrCreate(for: book.bookID) else {
        return nil
      }

      let timeRemaining = max(0, book.duration - mediaProgress.currentTime)

      return BookItem(
        id: book.bookID,
        title: book.title,
        author: book.authorNames,
        coverURL: book.coverURL,
        timeRemaining: timeRemaining,
        isDownloaded: book.isDownloaded
      )
    }

    self.books = items
  }

  override func fetch() async {
    isLoading = true
    defer { isLoading = false }

    do {
      let personalized = try await Audiobookshelf.shared.libraries.fetchPersonalized()

      let continueListeningBooks =
        personalized.sections
        .first(where: { $0.id == "continue-listening" })
        .flatMap { section -> [Book]? in
          if case .books(let books) = section.entities {
            return books
          }
          return nil
        } ?? []

      let userData = try await Audiobookshelf.shared.authentication.fetchMe()
      let progressByBookID = Dictionary(
        uniqueKeysWithValues: userData.mediaProgress.map { ($0.libraryItemId, $0) }
      )

      let items = await MainActor.run {
        continueListeningBooks.map { book in
          let timeRemaining: Double
          if let progress = progressByBookID[book.id] {
            timeRemaining = max(0, book.duration - progress.currentTime)
          } else {
            timeRemaining = book.duration
          }

          let isDownloaded: Bool
          if let item = try? LocalBook.fetch(bookID: book.id) {
            isDownloaded = item.isDownloaded
          } else {
            isDownloaded = false
          }

          return BookItem(
            id: book.id,
            title: book.title,
            author: book.authorName ?? "",
            coverURL: book.coverURL,
            timeRemaining: timeRemaining,
            isDownloaded: isDownloaded
          )
        }
      }

      self.books = items
    } catch {
      AppLogger.viewModel.error("Failed to fetch continue listening: \(error)")
    }
  }

  override func playBook(bookID: String) {
    Task {
      do {
        let book = try await Audiobookshelf.shared.books.fetch(id: bookID)

        await MainActor.run {
          playerManager.setCurrent(book)
          playerManager.isShowingFullPlayer = true
        }
      } catch {
        AppLogger.viewModel.error("Failed to fetch book: \(error)")
      }
    }
  }
}
