import Audiobookshelf
import Foundation

@MainActor
final class LibraryPageModel: LibraryPage.Model {
  private let audiobookshelf = Audiobookshelf.shared
  private let userProgressService = UserProgressService.shared

  private var fetched: [BookCard.Model] = []

  enum Filter {
    case series(String)
    case authors(String)
  }
  private var filter: Filter?

  private var currentPage: Int = 0
  private var hasMorePages: Bool = true
  private var isLoadingNextPage: Bool = false
  private let itemsPerPage: Int = 50

  init() {
    self.filter = nil

    super.init(
      isRoot: true,
      search: SearchViewModel(),
      title: "Library"
    )
  }

  init(series: Series) {
    self.filter = .series(series.id)

    super.init(
      isRoot: false,
      sortBy: nil,
      title: series.name
    )

    self.search = SearchViewModel()
  }

  init(author: Author) {
    self.filter = .authors(author.id)

    super.init(
      isRoot: false,
      sortBy: nil,
      title: author.name
    )

    self.search = SearchViewModel()
  }

  override func onAppear() {
    guard fetched.isEmpty else { return }

    Task {
      await loadBooks()
    }
  }

  override func refresh() async {
    currentPage = 0
    hasMorePages = true
    fetched.removeAll()
    books.removeAll()
    await userProgressService.refresh()
    await loadBooks()
  }

  override func onSortByTapped(_ sortBy: BooksService.SortBy) {
    if self.sortBy == sortBy {
      ascending.toggle()
    } else {
      self.sortBy = sortBy
      ascending = true
    }
    Task {
      await refresh()
    }
  }

  override func onSearchChanged(_ searchText: String) {
    if searchText.isEmpty {
      books = fetched
    } else {
      let searchTerm = searchText.lowercased()
      books = fetched.filter { book in
        book.title.lowercased().contains(searchTerm)
      }
    }
  }

  override func loadNextPageIfNeeded() {
    Task {
      await loadBooks()
    }
  }

  private func loadBooks() async {
    guard hasMorePages && !isLoadingNextPage && search.searchText.isEmpty else { return }

    isLoadingNextPage = true
    isLoading = currentPage == 0

    if currentPage == 0 {
      await userProgressService.refreshIfNeeded()
    }

    do {
      let filter: String?
      var sortBy = self.sortBy

      switch self.filter {
      case .series(let id):
        let base64SeriesID = Data(id.utf8).base64EncodedString()
        filter = "series.\(base64SeriesID)"

      case .authors(let id):
        let base64SeriesID = Data(id.utf8).base64EncodedString()
        filter = "authors.\(base64SeriesID)"
        sortBy = .title

      case nil:
        filter = nil
      }

      let response = try await audiobookshelf.books.fetch(
        limit: itemsPerPage,
        page: currentPage,
        sortBy: sortBy,
        ascending: ascending,
        filter: filter
      )

      let bookCards = response.results.map { book in
        if case .series = self.filter {
          BookCardModel(book, sortBy: .title)
        } else {
          BookCardModel(book, sortBy: self.sortBy)
        }
      }

      if currentPage == 0 {
        fetched = bookCards
      } else {
        fetched.append(contentsOf: bookCards)
      }

      if isRoot || search.searchText.isEmpty {
        books = fetched
      } else {
        let searchTerm = search.searchText.lowercased()
        books = fetched.filter { book in
          book.title.lowercased().contains(searchTerm)
        }
      }

      currentPage += 1

      hasMorePages = (currentPage * itemsPerPage) < response.total

    } catch {
      print("Failed to fetch library items: \(error)")
      if currentPage == 0 {
        fetched = []
        books = []
      }
    }

    isLoadingNextPage = false
    isLoading = false
  }
}
