import API
import SwiftUI

struct LibraryRootPage: View {
  @ObservedObject private var libraries = Audiobookshelf.shared.libraries

  var body: some View {
    NavigationStack {
      LibraryPage(model: LibraryPageModel())
        .id(libraries.current?.id)
        .navigationDestination(for: NavigationDestination.self) { destination in
          switch destination {
          case .book(let id):
            BookDetailsView(model: BookDetailsViewModel(bookID: id))
          case .offline:
            OfflineListView(model: OfflineListViewModel())
          case .author(let id, let name):
            AuthorDetailsView(model: AuthorDetailsViewModel(authorID: id, name: name))
          case .series, .narrator, .genre, .tag:
            LibraryPage(model: LibraryPageModel(destination: destination))
          case .playlist, .collection, .stats:
            EmptyView()
          }
        }
    }
  }
}
