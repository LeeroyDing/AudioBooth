import Foundation

struct RecentlyPlayedItemInfo: Codable, Identifiable {
  let bookID: String
  let title: String
  let author: String
  let coverURL: URL?
  let timeRemaining: Double

  var id: String { bookID }
}
