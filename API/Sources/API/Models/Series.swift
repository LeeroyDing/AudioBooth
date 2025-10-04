import Foundation

public struct Series: Codable, Sendable {
  public let id: String
  public let name: String
  public let addedAt: Int64?
  public let totalDuration: Double?
  public let books: [Book]

  private enum CodingKeys: String, CodingKey {
    case id
    case name
    case addedAt
    case totalDuration
    case books
    case series
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    if container.contains(.series) {
      let seriesContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .series)
      self.id = try seriesContainer.decode(String.self, forKey: .id)
      self.name = try seriesContainer.decode(String.self, forKey: .name)
      self.addedAt = try seriesContainer.decodeIfPresent(Int64.self, forKey: .addedAt)
      self.totalDuration = try seriesContainer.decodeIfPresent(Double.self, forKey: .totalDuration)
      self.books = try container.decode([Book].self, forKey: .books)
    } else {
      self.id = try container.decode(String.self, forKey: .id)
      self.name = try container.decode(String.self, forKey: .name)
      self.addedAt = try container.decodeIfPresent(Int64.self, forKey: .addedAt)
      self.totalDuration = try container.decodeIfPresent(Double.self, forKey: .totalDuration)
      self.books = try container.decode([Book].self, forKey: .books)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
    try container.encodeIfPresent(addedAt, forKey: .addedAt)
    try container.encodeIfPresent(totalDuration, forKey: .totalDuration)
    try container.encode(books, forKey: .books)
  }
}
