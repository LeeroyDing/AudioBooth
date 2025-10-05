import API
import Combine
import Models
import SwiftUI

struct BookDetailsView: View {
  @ObservedObject var model: Model

  private enum CoordinateSpaces {
    case scrollView
  }

  var body: some View {
    ScrollView {
      if model.isLoading {
        ProgressView("Loading book details...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        VStack(spacing: 0) {
          cover

          VStack(spacing: 16) {
            headerSection
            infoSection
            actionButtons
            if let chapters = model.chapters, !chapters.isEmpty {
              chaptersSection(chapters)
            }
          }
          .padding()
          .background()
        }
        .padding(.vertical)
      }
    }
    .coordinateSpace(name: CoordinateSpaces.scrollView)
    .ignoresSafeArea(edges: .top)
    .onAppear(perform: model.onAppear)
  }

  private var cover: some View {
    ParallaxHeader(coordinateSpace: CoordinateSpaces.scrollView) {
      ZStack(alignment: .bottom) {
        LazyImage(url: model.coverURL) { state in
          state.image?
            .resizable()
            .scaledToFill()
            .blur(radius: 5)
            .opacity(0.3)
        }

        CoverImage(url: model.coverURL)
          .frame(width: 250, height: 250)
          .overlay(alignment: .bottom) {
            if let progress = model.progress, progress > 0 {
              progressBar(progress)
            }
          }
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .shadow(radius: 4)
          .padding(24)
      }
    }
  }

  private var headerSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 8) {
        Text(model.title)
          .font(.title)
          .fontWeight(.bold)
          .multilineTextAlignment(.leading)

        if !model.authors.isEmpty {
          FlowLayout(spacing: 4) {
            ForEach(model.authors, id: \.id) { author in
              NavigationLink(value: NavigationDestination.author(id: author.id, name: author.name))
              {
                Chip(
                  title: author.name,
                  icon: "person.circle.fill",
                  color: .blue
                )
              }
            }
          }
        }

        if !model.series.isEmpty {
          FlowLayout(spacing: 4) {
            ForEach(model.series, id: \.id) { series in
              NavigationLink(value: NavigationDestination.series(id: series.id, name: series.name))
              {
                Chip(
                  title: series.sequence.isEmpty
                    ? series.name : "\(series.name) #\(series.sequence)",
                  icon: "square.stack.3d.up.fill",
                  color: .purple
                )
              }
            }
          }
        }
      }
    }
    .textSelection(.enabled)
  }

  private var infoSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let duration = model.durationText {
        HStack {
          Image(systemName: "clock")
          Text("Duration: \(duration)")
        }
        .font(.subheadline)
      }

      if let progress = model.progress, progress > 0 {
        HStack {
          Image(systemName: "chart.bar.fill")
          Text("Progress: \(progress.formatted(.percent.precision(.fractionLength(0))))")
        }
        .font(.subheadline)
      }

      if let timeRemaining = model.timeRemaining {
        HStack {
          Image(systemName: "clock.arrow.circlepath")
          Text("Time remaining: \(timeRemaining)")
        }
        .font(.subheadline)
      }

      downloadStateView
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private var downloadStateView: some View {
    switch model.downloadState {
    case .downloading(let progress):
      HStack {
        Image(systemName: "arrow.down.circle")
        Text("Downloading: \(progress.formatted(.percent.precision(.fractionLength(0))))")
        Spacer()
        Button("Cancel") {
          model.onDownloadTapped()
        }
      }
      .font(.subheadline)
    case .downloaded, .notDownloaded:
      EmptyView()
    }
  }

  private var actionButtons: some View {
    VStack(spacing: 12) {
      Button(action: model.onPlayTapped) {
        HStack {
          Image(systemName: playButtonIcon)
          Text(playButtonText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.accentColor)
        .foregroundColor(.white)
        .cornerRadius(12)
      }

      HStack(spacing: 12) {
        Button(role: downloadButtonRole, action: model.onDownloadTapped) {
          HStack {
            Image(systemName: downloadButtonIcon)
            Text(downloadButtonText)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding(8)
          .background(Color.secondary.opacity(0.2))
          .cornerRadius(12)
        }

        Button(action: model.onMarkFinishedTapped) {
          HStack {
            Image(systemName: markFinishedIcon)
            Text(markFinishedText)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding(8)
          .background(Color.secondary.opacity(0.2))
          .cornerRadius(12)
        }
      }
      .font(.subheadline)
    }
  }

  private var playButtonIcon: String {
    if let progress = model.progress, progress > 0 {
      return "play.circle.fill"
    }
    return "play.fill"
  }

  private var playButtonText: String {
    if model.isEbook {
      return "Read"
    }
    if let progress = model.progress, progress > 0 {
      return "Continue Listening"
    }
    return "Play"
  }

  private var downloadButtonRole: ButtonRole? {
    switch model.downloadState {
    case .downloading: nil
    case .downloaded: .destructive
    case .notDownloaded: nil
    }
  }

  private var downloadButtonIcon: String {
    switch model.downloadState {
    case .downloading:
      return "stop.circle"
    case .downloaded:
      return "trash"
    case .notDownloaded:
      return "arrow.down.circle"
    }
  }

  private var downloadButtonText: String {
    switch model.downloadState {
    case .downloading:
      return "Cancel"
    case .downloaded:
      return "Remove from Device"
    case .notDownloaded:
      return "Download"
    }
  }

  private var markFinishedIcon: String {
    if let progress = model.progress, progress >= 1.0 {
      return "checkmark.circle.fill"
    }
    return "checkmark.circle"
  }

  private var markFinishedText: String {
    if let progress = model.progress, progress >= 1.0 {
      return "Unfinish"
    }
    return "Finish"
  }

  private func progressBar(_ progress: Double) -> some View {
    GeometryReader { geometry in
      let progressColor: Color = progress >= 1.0 ? .green : .orange

      Rectangle()
        .fill(progressColor)
        .frame(width: geometry.size.width * progress, height: 8)
    }
    .frame(height: 8)
  }

  private func chaptersSection(_ chapters: [ChapterInfo]) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Chapters")
        .font(.headline)

      VStack(alignment: .leading, spacing: 8) {
        ForEach(chapters, id: \.id) { chapter in
          HStack {
            Text(chapter.title)
              .font(.subheadline)
              .frame(maxWidth: .infinity, alignment: .leading)

            Text(formatDuration(chapter.end - chapter.start))
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .padding(.vertical, 4)
        }
      }
      .padding()
      .background(Color.secondary.opacity(0.1))
      .cornerRadius(8)
    }
  }

  private func tracksSection(_ tracks: [AudioTrackInfo]) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Audio Files")
        .font(.headline)

      VStack(alignment: .leading, spacing: 8) {
        ForEach(Array(tracks.enumerated()), id: \.element.index) { index, track in
          HStack {
            Text(track.title ?? "Track \(index + 1)")
              .font(.subheadline)
            Spacer()
            Text(formatDuration(track.duration))
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .padding(.vertical, 4)
        }
      }
      .padding()
      .background(Color.secondary.opacity(0.1))
      .cornerRadius(8)
    }
  }

  private func formatDuration(_ seconds: Double) -> String {
    Duration.seconds(seconds).formatted(
      .units(
        allowed: [.hours, .minutes, .seconds],
        width: .narrow
      )
    )
  }
}

extension BookDetailsView {
  @Observable
  class Model: ObservableObject {
    let bookID: String
    var title: String
    var authors: [Author]
    var series: [Series]
    var coverURL: URL?
    var progress: Double?
    var durationText: String?
    var timeRemaining: String?
    var chapters: [ChapterInfo]?
    var tracks: [AudioTrackInfo]?
    var downloadState: DownloadManager.DownloadState
    var isLoading: Bool
    var isEbook: Bool

    func onAppear() {}
    func onPlayTapped() {}
    func onDownloadTapped() {}
    func onMarkFinishedTapped() {}

    init(
      bookID: String,
      title: String = "",
      authors: [Author] = [],
      series: [Series] = [],
      coverURL: URL? = nil,
      progress: Double? = nil,
      durationText: String? = nil,
      timeRemaining: String? = nil,
      chapters: [ChapterInfo]? = nil,
      tracks: [AudioTrackInfo]? = nil,
      downloadState: DownloadManager.DownloadState = .notDownloaded,
      isLoading: Bool = true,
      isEbook: Bool = false
    ) {
      self.bookID = bookID
      self.title = title
      self.authors = authors
      self.series = series
      self.coverURL = coverURL
      self.progress = progress
      self.durationText = durationText
      self.timeRemaining = timeRemaining
      self.chapters = chapters
      self.tracks = tracks
      self.downloadState = downloadState
      self.isLoading = isLoading
      self.isEbook = isEbook
    }
  }
}

extension BookDetailsView.Model {
  struct Author {
    let id: String
    let name: String
  }

  struct Series {
    let id: String
    let name: String
    let sequence: String
  }
}

extension BookDetailsView.Model {
  static var mock: BookDetailsView.Model {
    BookDetailsView.Model(
      bookID: "mock-id",
      title: "The Lord of the Rings",
      authors: [
        Author(id: "author-1", name: "J.R.R. Tolkien")
      ],
      series: [
        Series(id: "series-1", name: "The Lord of the Rings", sequence: "#1")
      ],
      coverURL: URL(string: "https://m.media-amazon.com/images/I/51YHc7SK5HL._SL500_.jpg"),
      progress: 0.45,
      durationText: "12hr 30min",
      timeRemaining: "6hr 52min",
      chapters: [
        .init(id: 1, start: 0, end: 1000, title: "001"),
        .init(id: 2, start: 1001, end: 2000, title: "002"),
        .init(id: 3, start: 2001, end: 3000, title: "003"),
        .init(id: 4, start: 3001, end: 4000, title: "004"),
        .init(id: 5, start: 4001, end: 5000, title: "005"),
        .init(id: 6, start: 5001, end: 6000, title: "006"),
      ],
      tracks: [],
      downloadState: .downloaded,
      isLoading: false
    )
  }
}

#Preview {
  NavigationStack {
    BookDetailsView(model: .mock)
  }
}

struct ParallaxHeader<Content: View, Space: Hashable>: View {
  let content: () -> Content
  let coordinateSpace: Space
  @State var height: CGFloat = 0

  init(
    coordinateSpace: Space,
    @ViewBuilder _ content: @escaping () -> Content
  ) {
    self.content = content
    self.coordinateSpace = coordinateSpace
  }

  var body: some View {
    GeometryReader { proxy in
      let offset = offset(for: proxy)
      let heightModifier = heightModifier(for: proxy)
      content()
        .edgesIgnoringSafeArea(.horizontal)
        .frame(
          width: proxy.size.width,
          height: proxy.size.height + heightModifier
        )
        .offset(y: offset)
        .onAppear { height = proxy.size.width }
        .onChange(of: proxy.size.width) { _, new in height = new }
    }
    .frame(height: height)
  }

  private func offset(for proxy: GeometryProxy) -> CGFloat {
    let frame = proxy.frame(in: .named(coordinateSpace))
    if frame.minY < 0 {
      return -frame.minY * 0.8
    }
    return -frame.minY
  }

  private func heightModifier(for proxy: GeometryProxy) -> CGFloat {
    let frame = proxy.frame(in: .named(coordinateSpace))
    return max(0, frame.minY)
  }
}
