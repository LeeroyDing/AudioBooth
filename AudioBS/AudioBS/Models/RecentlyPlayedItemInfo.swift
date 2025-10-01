import Foundation

struct RecentlyPlayedItemInfo: Codable, Identifiable {
  let bookID: String
  let title: String
  let author: String
  let coverURL: URL?
  let timeRemaining: Double

  var id: String { bookID }

  init(
    bookID: String,
    title: String,
    author: String,
    coverURL: URL?,
    timeRemaining: Double
  ) {
    self.bookID = bookID
    self.title = title
    self.author = author
    self.coverURL = coverURL
    self.timeRemaining = timeRemaining
  }

  init(from item: RecentlyPlayedItem) {
    self.bookID = item.bookID
    self.title = item.title
    self.author = item.author ?? ""
    self.coverURL = item.coverURL
    if let mediaProgress = try? MediaProgress.fetch(bookID: item.bookID) {
      self.timeRemaining = max(0, mediaProgress.duration - mediaProgress.currentTime)
    } else {
      self.timeRemaining = 0
    }
  }
}
