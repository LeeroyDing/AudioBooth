import Audiobookshelf
import Foundation

@MainActor
final class BookCardModel: BookCard.Model {
  private var playerManager = PlayerManager.shared
  private var userProgressService = UserProgressService.shared

  private let book: Book

  init(_ item: Book, sortBy: BooksService.SortBy?) {
    let id = item.id

    let details: String?
    switch sortBy {
    case .publishedYear:
      details = item.publishedYear.map({ "Published \($0)" })
    case .title, .authorName, .authorNameLF:
      details = item.authorName
    case .addedAt:
      details =
        "Added \(DateFormatter.localizedString(from: item.addedAt, dateStyle: .short, timeStyle: .none))"
    case .updatedAt:
      details =
        "Updated \(DateFormatter.localizedString(from: item.updatedAt, dateStyle: .short, timeStyle: .none))"
    case .size:
      details = item.size.map {
        "Size \(ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file))"
      }
    case .duration:
      details = Duration.seconds(item.duration).formatted(
        .units(
          allowed: [.hours, .minutes, .seconds],
          width: .narrow
        )
      )
    case nil:
      details = nil
    }

    self.book = item

    super.init(
      id: id,
      title: item.title,
      details: details,
      coverURL: item.coverURL,
      sequence: item.sequence,
      progress: userProgressService.progressByBookID[id]?.progress
    )
  }

  @MainActor
  override func onTapped() {
    playerManager.setCurrent(book)
  }
}
