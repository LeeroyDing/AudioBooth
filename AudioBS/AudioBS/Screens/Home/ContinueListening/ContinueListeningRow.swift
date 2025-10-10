import API
import SwiftUI

struct ContinueListeningRow: View {
  @Bindable var model: Model

  var body: some View {
    NavigationLink(value: NavigationDestination.book(id: model.bookID)) {
      HStack(spacing: 8) {
        cover

        VStack(alignment: .leading, spacing: 16) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
              title
              author
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu(
              content: { contextMenu },
              label: {
                Image(systemName: "ellipsis")
                  .font(.headline)
                  .foregroundColor(.primary)
                  .padding(.vertical, 10)
                  .padding(.leading, 4)
                  .contentShape(Rectangle())
              }
            )
          }

          if let timeRemaining = model.timeRemaining {
            Text("\(timeRemaining)")
              .font(.caption)
              .foregroundColor(.secondary)
          }

          progressInfo
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color(.systemGray6))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(.gray.opacity(0.3), lineWidth: 1)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .contextMenu { contextMenu }
    .onAppear(perform: model.onAppear)
  }

  var cover: some View {
    CoverImage(url: model.coverURL)
      .frame(width: 100, height: 100)
      .overlay(alignment: .bottom) {
        progressBar
      }
      .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  var title: some View {
    Text(model.title)
      .font(.headline)
      .lineLimit(2)
      .foregroundColor(.primary)
      .multilineTextAlignment(.leading)
  }

  @ViewBuilder
  var author: some View {
    if let author = model.author {
      Text(author)
        .font(.subheadline)
        .foregroundColor(.secondary)
        .lineLimit(1)
    }
  }

  var progressInfo: some View {
    HStack {
      if let progress = model.progress {
        Text(progress.formatted(.percent.precision(.fractionLength(0))))
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Spacer()

      if let lastPlayedAt = model.lastPlayedAt {
        if lastPlayedAt == .distantFuture {
          Text("Playing now")
            .font(.caption)
            .foregroundColor(.blue)
        } else {
          Text(lastPlayedAt, style: .relative)
            .font(.caption)
            .foregroundColor(.secondary)
            .monospacedDigit()
        }
      }
    }
  }

  @ViewBuilder
  var contextMenu: some View {
    Button {
      model.onRemoveFromListTapped()
    } label: {
      Label("Remove from continue listening", systemImage: "eye.slash")
    }
  }

  @ViewBuilder
  var progressBar: some View {
    if let progress = model.progress, progress > 0 {
      GeometryReader { geometry in
        let progressColor: Color = progress >= 1.0 ? .green : .orange

        Rectangle()
          .fill(progressColor)
          .frame(width: geometry.size.width * progress, height: 4)
      }
      .frame(height: 4)
    }
  }

}

extension ContinueListeningRow {
  @Observable
  class Model: Comparable, Identifiable {
    let bookID: String
    let title: String
    let author: String?
    let coverURL: URL?
    var progress: Double?
    var lastPlayedAt: Date?
    var timeRemaining: String?

    func onAppear() {}
    func onRemoveFromListTapped() {}

    init(
      bookID: String = UUID().uuidString,
      title: String,
      author: String?,
      coverURL: URL?,
      progress: Double?,
      lastPlayedAt: Date?,
      timeRemaining: String? = nil
    ) {
      self.bookID = bookID
      self.title = title
      self.author = author
      self.coverURL = coverURL
      self.progress = progress
      self.lastPlayedAt = lastPlayedAt
      self.timeRemaining = timeRemaining
    }

    static func == (lhs: ContinueListeningRow.Model, rhs: ContinueListeningRow.Model) -> Bool {
      lhs.id == rhs.id
    }

    static func < (lhs: ContinueListeningRow.Model, rhs: ContinueListeningRow.Model) -> Bool {
      switch (lhs.lastPlayedAt, rhs.lastPlayedAt) {
      case (.none, .none): false
      case (.some, .none): false
      case (.none, .some): true
      case let (.some(lhs), .some(rhs)): lhs < rhs
      }
    }
  }
}

extension ContinueListeningRow.Model {
  static let mock = ContinueListeningRow.Model(
    title: "The Lord of the Rings",
    author: "J.R.R. Tolkien",
    coverURL: URL(string: "https://m.media-amazon.com/images/I/51YHc7SK5HL._SL500_.jpg"),
    progress: 0.45,
    lastPlayedAt: Date().addingTimeInterval(-3600),
    timeRemaining: "8hr 32min remaining"
  )
}

#Preview("ContinueListeningRow") {
  ScrollView {
    ContinueListeningRow(model: .mock)
      .padding()
  }
}
