import API
import Foundation

final class LibraryPageModel: LibraryPage.Model {
  private let audiobookshelf = Audiobookshelf.shared

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

  init(destination: NavigationDestination) {
    switch destination {
    case .series(let id, let name):
      self.filter = .series(id)
      super.init(
        isRoot: false,
        sortBy: nil,
        title: name
      )
    case .author(let id, let name):
      self.filter = .authors(id)
      super.init(
        isRoot: false,
        sortBy: nil,
        title: name
      )
    case .book:
      fatalError("LibraryPageModel cannot be initialized with a book destination")
    }

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
      if currentPage == 0 {
        fetched = []
        books = []
      }
    }

    isLoadingNextPage = false
    isLoading = false
  }
}
