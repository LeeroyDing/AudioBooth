import Foundation

public struct Library: Codable, Sendable, Equatable {
  public let id: String
  public let name: String
  public let serverID: String

  public init(id: String, name: String, serverID: String = "") {
    self.id = id
    self.name = name
    self.serverID = serverID
  }

  enum CodingKeys: String, CodingKey {
    case id
    case name
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    serverID = Audiobookshelf.shared.authentication.server?.id ?? ""
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
  }
}
