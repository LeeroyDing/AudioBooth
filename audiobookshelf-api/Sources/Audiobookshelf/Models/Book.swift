import Foundation

public struct Book: Decodable, Sendable {
  public let id: String
  public let libraryID: String
  public let title: String
  public let duration: Double
  public let numAudioFiles: Int
  public let authorName: String?
  public let publishedYear: String?
  public let size: Int?
  public let addedAt: Date
  public let updatedAt: Date
  public let sequence: String?

  public var coverURL: URL? {
    guard let serverURL = Audiobookshelf.shared.serverURL else { return nil }
    return serverURL.appendingPathComponent(
      "audiobookshelf/api/items/\(id)/cover")
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case libraryId
    case media
    case addedAt
    case updatedAt
  }

  private enum MediaKeys: String, CodingKey {
    case metadata
    case duration
    case numAudioFiles
    case size
  }

  private enum MetadataKeys: String, CodingKey {
    case title
    case authorName
    case series
    case publishedYear
  }

  private enum SeriesKeys: String, CodingKey {
    case sequence
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.id = try container.decode(String.self, forKey: .id)
    self.libraryID = try container.decode(String.self, forKey: .libraryId)

    let addedAtMs = try container.decode(Int.self, forKey: .addedAt)
    self.addedAt = Date(timeIntervalSince1970: TimeInterval(addedAtMs) / 1000.0)

    let updatedAtMs = try container.decode(Int.self, forKey: .updatedAt)
    self.updatedAt = Date(timeIntervalSince1970: TimeInterval(updatedAtMs) / 1000.0)

    let mediaContainer = try container.nestedContainer(keyedBy: MediaKeys.self, forKey: .media)
    self.duration = try mediaContainer.decodeIfPresent(Double.self, forKey: .duration) ?? 0

    let metadataContainer = try mediaContainer.nestedContainer(
      keyedBy: MetadataKeys.self, forKey: .metadata)
    self.title = try metadataContainer.decode(String.self, forKey: .title)

    self.numAudioFiles = try mediaContainer.decodeIfPresent(Int.self, forKey: .numAudioFiles) ?? 0
    self.authorName = try metadataContainer.decodeIfPresent(String.self, forKey: .authorName)
    self.publishedYear = try metadataContainer.decodeIfPresent(String.self, forKey: .publishedYear)
    self.size = try mediaContainer.decodeIfPresent(Int.self, forKey: .size)

    let seriesContainer = try? metadataContainer.nestedContainer(
      keyedBy: SeriesKeys.self, forKey: .series)
    self.sequence = try seriesContainer?.decodeIfPresent(String.self, forKey: .sequence)
  }
}
