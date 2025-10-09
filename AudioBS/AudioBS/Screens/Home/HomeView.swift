import API
import Combine
import SwiftData
import SwiftUI

struct HomeView: View {
  @StateObject var model: Model
  @State private var showingDeleteConfirmation = false
  @State private var showingSettings = false
  @ObservedObject private var libraries = Audiobookshelf.shared.libraries

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        if let recents = model.recents {
          sectionContent(recents)
        }

        if let offline = model.offline {
          sectionContent(offline)
        }

        if model.isLoading && model.others.isEmpty {
          ProgressView("Loading...")
            .frame(maxWidth: .infinity, maxHeight: 200)
        } else if model.others.isEmpty && !model.isLoading {
          if model.recents == nil && model.offline == nil {
            emptyState
          } else {
            emptyPersonalizedState
          }
        } else {
          ForEach(model.others, id: \.title) { section in
            sectionContent(section)
          }
        }
      }
    }
    .navigationTitle(model.title)
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button {
          showingSettings = true
        } label: {
          Image(systemName: "gear")
        }
      }
    }
    .sheet(isPresented: $showingSettings) {
      NavigationView {
        SettingsView(model: SettingsViewModel())
      }
    }
    .onAppear {
      if libraries.current == nil {
        showingSettings = true
      }
      model.onAppear()
    }
    .onChange(of: libraries.current) { _, new in
      model.onReset(new != nil)
    }
    .refreshable {
      await model.refresh()
    }
  }

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "headphones")
        .font(.system(size: 60))
        .foregroundColor(.gray.opacity(0.6))

      Text("No Content Available")
        .font(.title2)
        .fontWeight(.medium)
        .foregroundColor(.primary)

      Text("Your personalized content will appear here")
        .font(.body)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)

      Spacer()
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var emptyPersonalizedState: some View {
    VStack(spacing: 16) {
      Text("No additional content available")
        .font(.title3)
        .fontWeight(.medium)
        .foregroundColor(.secondary)
        .padding(.top, 32)

      Spacer()
    }
    .frame(maxWidth: .infinity, minHeight: 100)
  }

  @ViewBuilder
  private func sectionContent(_ section: HomeView.Model.Section) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(section.title)
        .font(.title2)
        .fontWeight(.semibold)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)

      switch section.items {
      case .recents(let items):
        VStack(spacing: 8) {
          ForEach(items) { item in
            RecentRow(model: item)
          }
        }
        .padding(.horizontal)

      case .books(let items):
        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(spacing: 16) {
            ForEach(items, id: \.id) { book in
              BookCard(model: book)
                .frame(width: 120)
            }
          }
          .padding(.horizontal)
        }

      case .series(let items):
        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(spacing: 16) {
            ForEach(items, id: \.id) { series in
              SeriesCard(model: series, titleFont: .footnote)
                .frame(width: 240)
            }
          }
          .padding(.horizontal)
        }

      case .authors(let items):
        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(spacing: 16) {
            ForEach(items, id: \.id) { author in
              AuthorCard(model: author)
                .frame(width: 80)
            }
          }
          .padding(.horizontal)
        }
      }
    }
  }
}

extension HomeView {
  @Observable class Model: ObservableObject {
    var isLoading: Bool
    var isRoot: Bool
    var title: String

    struct Section {
      let title: String

      enum Items {
        case books([BookCard.Model])
        case series([SeriesCard.Model])
        case authors([AuthorCard.Model])
        case recents([RecentRow.Model])
      }
      let items: Items
    }

    var recents: Section?
    var offline: Section?
    var others: [Section]

    func onAppear() {}
    func refresh() async {}
    func onReset(_ shouldRefresh: Bool) {}

    init(
      isLoading: Bool = false,
      isRoot: Bool = true,
      title: String = "Home",
      recents: Section? = nil,
      offline: Section? = nil,
      others: [Section] = []
    ) {
      self.isLoading = isLoading
      self.isRoot = isRoot
      self.title = title
      self.recents = recents
      self.offline = offline
      self.others = others
    }
  }
}

extension HomeView.Model {
  static var mock: HomeView.Model {
    let sampleRecentItems: [RecentRow.Model] = [
      RecentRow.Model(
        title: "The Lord of the Rings",
        author: "J.R.R. Tolkien",
        coverURL: URL(string: "https://m.media-amazon.com/images/I/51YHc7SK5HL._SL500_.jpg"),
        progress: 0.45,
        lastPlayedAt: Date().addingTimeInterval(-3600)
      ),
      RecentRow.Model(
        title: "Dune",
        author: "Frank Herbert",
        coverURL: URL(string: "https://m.media-amazon.com/images/I/41rrXYM-wHL._SL500_.jpg"),
        progress: 0.12,
        lastPlayedAt: Date().addingTimeInterval(-7200)
      ),
    ]

    return HomeView.Model(
      recents: Section(title: "Continue Listening", items: .recents(sampleRecentItems))
    )
  }
}

#Preview("HomeView - Loading") {
  HomeView(model: .init(isLoading: true))
}

#Preview("HomeView - Empty") {
  HomeView(model: .init())
}

#Preview("HomeView - With Recent Items") {
  HomeView(model: .mock)
}
