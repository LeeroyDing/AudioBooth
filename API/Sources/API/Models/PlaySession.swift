import Foundation

public struct PlaySession: Codable, Sendable {
  public let id: String
  public let userId: String
  public let libraryItemId: String
  public let currentTime: Double
  public let duration: Double
  public let audioTracks: [Book.Media.Track]?
  public let chapters: [Book.Media.Chapter]?
  public let libraryItem: Book?

  public struct StreamingTrack {
    public var track: Book.Media.Track
    public var url: URL
  }

  public var streamingTracks: [StreamingTrack]? {
    guard let serverURL = Audiobookshelf.shared.authentication.serverURL, let audioTracks else {
      return nil
    }

    let baseURL = serverURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

    var tracks = [StreamingTrack]()
    for track in audioTracks {
      let streamingPath = "/public/session/\(id)/track/\(track.index)"
      guard let url = URL(string: "\(baseURL)\(streamingPath)") else { return nil }
      tracks.append(StreamingTrack(track: track, url: url))
    }

    return tracks
  }
}
