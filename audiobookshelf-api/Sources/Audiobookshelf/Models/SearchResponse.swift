import Foundation

public struct SearchResponse: Decodable, Sendable {
  public let book: [SearchBook]
  public let series: [Series]
  public let authors: [Author]
}

public struct SearchBook: Decodable, Sendable {
  public let libraryItem: Book
}
