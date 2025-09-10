import Foundation

public struct PersonalizedSection: Decodable, Identifiable {
  public let id: String
  public let label: String

  public enum Entities {
    case books([Book])
    case series([Series])
  }
  public let entities: Entities

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(String.self, forKey: .id)
    label = try container.decode(String.self, forKey: .label)

    enum Section: String, Decodable {
      case book
      case series
    }
    let type = try container.decode(Section.self, forKey: .type)

    switch type {
    case .book:
      let books = try container.decode([Book].self, forKey: .entities)
      entities = .books(books)
    case .series:
      let series = try container.decode([Series].self, forKey: .entities)
      entities = .series(series)
    }
  }

  enum CodingKeys: String, CodingKey {
    case id, label, labelStringKey, type, entities, total
  }
}
