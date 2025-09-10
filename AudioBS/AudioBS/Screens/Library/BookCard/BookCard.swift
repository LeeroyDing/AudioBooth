import Audiobookshelf
import Combine
import SwiftUI

struct BookCard: View {
  @Bindable var model: Model

  var body: some View {
    Button(
      action: { model.onTapped() },
      label: {
        VStack(alignment: .leading, spacing: 8) {
          cover

          VStack(alignment: .leading, spacing: 4) {
            title
            details
          }
          .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topTrailing) {
          if let sequence = model.sequence {
            Text("#\(sequence)")
              .font(.caption2)
              .foregroundStyle(Color.white)
              .padding(.vertical, 2)
              .padding(.horizontal, 4)
              .background(Color.black.opacity(0.6))
              .clipShape(Capsule())
              .padding(4)
          }
        }
      }
    )
  }

  var cover: some View {
    LazyImage(url: model.coverURL) { state in
      if let image = state.image {
        image
          .resizable()
          .aspectRatio(1, contentMode: .fit)
      } else {
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.gray.opacity(0.3))
          .aspectRatio(1, contentMode: .fit)
          .overlay {
            Image(systemName: "book.closed")
              .foregroundColor(.gray)
              .font(.title2)
          }
      }
    }
    .overlay(alignment: .bottom) {
      progressBar
    }
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .shadow(radius: 2)
  }

  var title: some View {
    Text(model.title)
      .font(.caption)
      .foregroundColor(.primary)
      .fontWeight(.medium)
      .lineLimit(1)
      .allowsTightening(true)
  }

  @ViewBuilder
  var details: some View {
    if let details = model.details {
      Text(details)
        .font(.caption2)
        .foregroundColor(.secondary)
        .lineLimit(1)
        .allowsTightening(true)
    }
  }

  @ViewBuilder
  var progressBar: some View {
    if let progress = model.progress, progress > 0 {
      GeometryReader { geometry in
        let progressColor: Color = progress >= 1.0 ? .green : .orange

        RoundedRectangle(cornerRadius: 2)
          .fill(progressColor)
          .frame(width: geometry.size.width * progress, height: 4)
      }
      .frame(height: 4)
    }
  }
}

extension BookCard {
  @Observable class Model: Identifiable {
    let id: String
    let title: String
    let details: String?
    let coverURL: URL?
    let sequence: String?
    let progress: Double?

    @MainActor func onTapped() {}

    init(
      id: String = UUID().uuidString,
      title: String,
      details: String?,
      coverURL: URL?,
      sequence: String? = nil,
      progress: Double? = nil
    ) {
      self.id = id
      self.title = title
      self.details = details
      self.coverURL = coverURL
      self.sequence = sequence
      self.progress = progress
    }
  }
}

extension BookCard.Model {
  static let mock = BookCard.Model(
    title: "The Lord of the Rings",
    details: "J.R.R. Tolkien",
    coverURL: URL(string: "https://m.media-amazon.com/images/I/51YHc7SK5HL._SL500_.jpg")
  )
}

#Preview("BookCard") {
  LazyVGrid(
    columns: [
      GridItem(spacing: 12, alignment: .top),
      GridItem(spacing: 12, alignment: .top),
      GridItem(spacing: 12, alignment: .top),
    ],
    spacing: 20,
  ) {
    BookCard(
      model: BookCard.Model(
        title: "The Lord of the Rings",
        details: "J.R.R. Tolkien",
        coverURL: URL(string: "https://m.media-amazon.com/images/I/51YHc7SK5HL._SL500_.jpg")
      )
    )
    BookCard(
      model: BookCard.Model(
        title: "Dune",
        details: "Frank Herbert",
        coverURL: URL(string: "https://m.media-amazon.com/images/I/41rrXYM-wHL._SL500_.jpg")
      )
    )
    BookCard(
      model: BookCard.Model(
        title: "The Foundation",
        details: "Isaac Asimov",
        coverURL: URL(string: "https://m.media-amazon.com/images/I/51I5xPlDi9L._SL500_.jpg")
      )
    )
  }
  .padding()
}
