import Audiobookshelf
import Foundation

@MainActor
final class AuthorCardModel: AuthorCard.Model {
  init(author: Author) {
    super.init(
      id: author.id,
      name: author.name,
      bookCount: author.numBooks ?? 0,
      imageURL: author.imageURL,
      library: LibraryPageModel(author: author)
    )
  }
}
