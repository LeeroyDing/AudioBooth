import Foundation

public struct PlaySession: Codable, Sendable {
  public let id: String
  public let userId: String
  public let libraryItemId: String
  public let currentTime: Double
  public let duration: Double
  public let audioTracks: [Track]?
  public let chapters: [Chapter]?

  private var serverURL: URL?

  public struct Track: Codable, Sendable {
    public let index: Int
    public let startOffset: Double
    public let duration: Double
    public let title: String?
    public let contentUrl: String?
    public let mimeType: String?
    public let codec: String?
    public let metadata: Metadata?
    public let updatedAt: Int64?

    public struct Metadata: Codable, Sendable {
      public let filename: String?
      public let ext: String?
      public let size: Int64?
      public let duration: Double?
    }
  }

  public struct Chapter: Codable, Sendable {
    public let id: Int
    public let start: Double
    public let end: Double
    public let title: String
  }

  mutating func setServerURL(_ url: URL) {
    serverURL = url
  }

  public func streamingURL(at time: Double) -> URL? {
    guard let serverURL = serverURL else { return nil }
    guard let tracks = audioTracks, !tracks.isEmpty else { return nil }

    let baseURL = serverURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

    if tracks.count == 1 {
      let track = tracks[0]
      let streamingPath = "/public/session/\(id)/track/\(track.index)"
      var urlString = "\(baseURL)\(streamingPath)"

      if time > 0 {
        urlString += "?t=\(Int(time))"
      }

      return URL(string: urlString)
    }

    var currentTime: Double = 0
    for track in tracks {
      let trackEndTime = currentTime + track.duration

      if time >= currentTime && time < trackEndTime {
        let trackTime = time - currentTime
        let streamingPath = "/public/session/\(id)/track/\(track.index)"
        var urlString = "\(baseURL)\(streamingPath)"

        if trackTime > 0 {
          urlString += "?t=\(Int(trackTime))"
        }

        return URL(string: urlString)
      }

      currentTime = trackEndTime
    }

    return streamingURL(for: 0)
  }

  public func streamingURL(for trackIndex: Int) -> URL? {
    guard let serverURL = serverURL else { return nil }

    let baseURL = serverURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let streamingPath = "/public/session/\(id)/track/\(trackIndex)"
    return URL(string: "\(baseURL)\(streamingPath)")
  }

  public func streamingURLs() -> [URL] {
    guard let tracks = audioTracks else { return [] }

    return tracks.compactMap { track in
      streamingURL(for: track.index)
    }
  }
}
