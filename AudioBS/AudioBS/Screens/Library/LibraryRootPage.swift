import SwiftUI

struct LibraryRootPage: View {
  @State private var path = NavigationPath()

  var body: some View {
    NavigationStack(path: $path) {
      LibraryPage(model: LibraryPageModel())
        .environment(\.navigationPath, $path)
        .navigationDestination(for: NavigationDestination.self) { destination in
          switch destination {
          case .book(let id):
            BookDetailsView(model: BookDetailsViewModel(bookID: id))
          case .series, .author:
            LibraryPage(model: LibraryPageModel(destination: destination))
          }
        }
    }
  }
}
