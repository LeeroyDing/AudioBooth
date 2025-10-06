import API
import SwiftData
import SwiftUI

struct ContentView: View {
  @StateObject private var playerManager = PlayerManager.shared
  @ObservedObject private var libraries = Audiobookshelf.shared.libraries
  @Environment(\.scenePhase) private var scenePhase

  @State var miniPlayerHeight: CGFloat = 0.0
  @State private var isKeyboardVisible = false
  @State private var selectedTab: TabSelection = .home

  enum TabSelection {
    case home, library, series, authors, search
  }

  private var hasSelectedLibrary: Bool {
    libraries.current != nil
  }

  var body: some View {
    Group {
      if #available(iOS 26.0, *) {
        modernTabView
      } else {
        legacyTabView
      }
    }
    .sheet(isPresented: $playerManager.isShowingFullPlayer) {
      if let currentPlayer = playerManager.current {
        BookPlayer(model: .constant(currentPlayer))
          .presentationDetents([.large])
          .presentationDragIndicator(.visible)
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification))
    { _ in
      isKeyboardVisible = true
    }
    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification))
    { _ in
      isKeyboardVisible = false
    }
    .onChange(of: scenePhase) { _, newPhase in
      AppStateManager.shared.updateScenePhase(newPhase)
    }

  }

  @available(iOS 26.0, *)
  @ViewBuilder
  private var modernTabView: some View {
    TabView(selection: $selectedTab) {
      Tab("Home", systemImage: "house", value: .home) {
        NavigationStack {
          HomeView(model: HomeViewModel())
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

      if hasSelectedLibrary {
        Tab("Library", systemImage: "books.vertical.fill", value: .library) {
          NavigationStack {
            LibraryPage(model: LibraryPageModel())
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

        Tab("Series", systemImage: "square.stack.3d.up.fill", value: .series) {
          NavigationStack {
            SeriesPage(model: SeriesPageModel())
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

        Tab("Authors", systemImage: "person.crop.rectangle.stack", value: .authors) {
          NavigationStack {
            AuthorsPage(model: AuthorsPageModel())
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

        Tab("Search", systemImage: "magnifyingglass", value: .search, role: .search) {
          NavigationStack {
            SearchPage(model: SearchViewModel())
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
    }
    .tabBarMinimizeBehavior(.onScrollDown)
    .tabViewBottomAccessory {
      if let currentPlayer = playerManager.current, !isKeyboardVisible {
        MiniBookPlayer(player: currentPlayer)
          .glassEffect()
      }
    }
  }

  @ViewBuilder
  private var legacyTabView: some View {
    TabView {
      NavigationStack {
        HomeView(model: HomeViewModel())
          .safeAreaInset(edge: .bottom) { miniPlayerOffsetView }
          .navigationDestination(for: NavigationDestination.self) { destination in
            switch destination {
            case .book(let id):
              BookDetailsView(model: BookDetailsViewModel(bookID: id))
            case .series, .author:
              LibraryPage(model: LibraryPageModel(destination: destination))
            }
          }
      }
      .tabItem {
        Image(systemName: "house")
        Text("Home")
      }

      if hasSelectedLibrary {
        NavigationStack {
          LibraryPage(model: LibraryPageModel())
            .safeAreaInset(edge: .bottom) { miniPlayerOffsetView }
            .navigationDestination(for: NavigationDestination.self) { destination in
              switch destination {
              case .book(let id):
                BookDetailsView(model: BookDetailsViewModel(bookID: id))
              case .series, .author:
                LibraryPage(model: LibraryPageModel(destination: destination))
              }
            }
        }
        .tabItem {
          Image(systemName: "books.vertical.fill")
          Text("Library")
        }

        NavigationStack {
          SeriesPage(model: SeriesPageModel())
            .safeAreaInset(edge: .bottom) { miniPlayerOffsetView }
            .navigationDestination(for: NavigationDestination.self) { destination in
              switch destination {
              case .book(let id):
                BookDetailsView(model: BookDetailsViewModel(bookID: id))
              case .series, .author:
                LibraryPage(model: LibraryPageModel(destination: destination))
              }
            }
        }
        .tabItem {
          Image(systemName: "square.stack.3d.up.fill")
          Text("Series")
        }

        NavigationStack {
          AuthorsPage(model: AuthorsPageModel())
            .safeAreaInset(edge: .bottom) { miniPlayerOffsetView }
            .navigationDestination(for: NavigationDestination.self) { destination in
              switch destination {
              case .book(let id):
                BookDetailsView(model: BookDetailsViewModel(bookID: id))
              case .series, .author:
                LibraryPage(model: LibraryPageModel(destination: destination))
              }
            }
        }
        .tabItem {
          Image(systemName: "person.crop.rectangle.stack")
          Text("Authors")
        }
      }

    }
    .safeAreaInset(edge: .bottom) { miniPlayer.padding(.bottom, 49) }
  }

  @ViewBuilder
  private var miniPlayer: some View {
    if let currentPlayer = playerManager.current, !isKeyboardVisible {
      LegacyMiniBookPlayer(player: currentPlayer)
        .id(currentPlayer.id)
        .transition(.move(edge: .bottom))
        .animation(.easeInOut(duration: 0.3), value: playerManager.hasActivePlayer)
        .overlay {
          GeometryReader { geometry in
            Color.clear.onAppear {
              miniPlayerHeight = geometry.size.height
            }
          }
        }
    }
  }

  @ViewBuilder
  private var miniPlayerOffsetView: some View {
    if playerManager.current != nil {
      Color.clear.frame(height: miniPlayerHeight)
    }
  }
}

#Preview {
  ContentView()
}
