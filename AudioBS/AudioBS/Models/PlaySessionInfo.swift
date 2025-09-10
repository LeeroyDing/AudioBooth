import Audiobookshelf
import Foundation
import SwiftData

@Model
final class PlaySessionInfo {
  var id: String
  var createdAt: Date
  var userId: String
  var libraryItemID: String
  var sessionType: String?
  var playMethod: Int?
  var mediaType: String?
  var audioTracks: [AudioTrackInfo]?
  var chapters: [ChapterInfo]?

  init(from session: PlaySession) {
    self.id = session.id
    self.createdAt = Date()
    self.userId = session.userId
    self.libraryItemID = session.libraryItemId
    self.sessionType = session.sessionType
    self.playMethod = session.playMethod
    self.mediaType = session.mediaType
    self.audioTracks = session.audioTracks?.map(AudioTrackInfo.init)
    self.chapters = session.chapters?.map(ChapterInfo.init)
  }
}

extension PlaySessionInfo {
  var isExpired: Bool {
    if hasLocalFiles {
      return false
    }

    return Date().timeIntervalSince(createdAt) > 24 * 60 * 60
  }

  var hasLocalFiles: Bool {
    guard let tracks = orderedTracks, !tracks.isEmpty else {
      return false
    }

    return tracks.allSatisfy { track in
      guard let localPath = track.localFilePath else { return false }
      return FileManager.default.fileExists(atPath: localPath)
    }
  }

  var orderedChapters: [ChapterInfo]? {
    chapters?.sorted(by: { $0.start < $1.start })
  }

  var orderedTracks: [AudioTrackInfo]? {
    audioTracks?.sorted(by: { $0.index < $1.index })
  }

  func streamingURL(at time: Double, serverURL: URL) -> URL? {
    guard let tracks = orderedTracks, !tracks.isEmpty else { return nil }

    if tracks.count == 1 {
      let track = tracks[0]

      if let localPath = track.localFilePath,
        FileManager.default.fileExists(atPath: localPath)
      {
        return URL(fileURLWithPath: localPath)
      }

      let baseURL = serverURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      let streamingPath = "/public/session/\(id)/track/\(track.index)"
      var urlString = "\(baseURL)\(streamingPath)"

      if time > 0 {
        urlString += "?t=\(time)"
      }

      return URL(string: urlString)
    }

    var currentTime: Double = 0
    for track in tracks {
      if time >= currentTime && time < currentTime + track.duration {

        if let localPath = track.localFilePath,
          FileManager.default.fileExists(atPath: localPath)
        {
          return URL(fileURLWithPath: localPath)
        }

        let trackOffset = time - currentTime
        let baseURL = serverURL.absoluteString.trimmingCharacters(
          in: CharacterSet(charactersIn: "/"))
        let streamingPath = "/public/session/\(id)/track/\(track.index)"
        let urlString = "\(baseURL)\(streamingPath)?t=\(trackOffset)"
        return URL(string: urlString)
      }
      currentTime += track.duration
    }

    return nil
  }

  func streamingURL(for trackIndex: Int, serverURL: URL) -> URL? {
    if let track = orderedTracks?.first(where: { $0.index == trackIndex }),
      let localPath = track.localFilePath,
      FileManager.default.fileExists(atPath: localPath)
    {
      return URL(fileURLWithPath: localPath)
    }

    let baseURL = serverURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let streamingPath = "/public/session/\(id)/track/\(trackIndex)"
    return URL(string: "\(baseURL)\(streamingPath)")
  }

  func streamingURLs(serverURL: URL) -> [URL] {
    guard let tracks = orderedTracks else { return [] }

    return tracks.compactMap { track in
      streamingURL(for: track.index, serverURL: serverURL)
    }
  }

  func merge(with newSessionInfo: PlaySessionInfo) {
    self.id = newSessionInfo.id
    self.createdAt = newSessionInfo.createdAt
    self.userId = newSessionInfo.userId
    self.libraryItemID = newSessionInfo.libraryItemID
    self.sessionType = newSessionInfo.sessionType
    self.playMethod = newSessionInfo.playMethod
    self.mediaType = newSessionInfo.mediaType
    self.chapters = newSessionInfo.chapters

    guard let newTracks = newSessionInfo.audioTracks else {
      self.audioTracks = nil
      return
    }

    var mergedTracks: [AudioTrackInfo] = []

    for newTrack in newTracks {
      if let existingTrack = self.audioTracks?.first(where: { $0.index == newTrack.index }) {
        if let existingUpdatedAt = existingTrack.updatedAt,
          let newUpdatedAt = newTrack.updatedAt,
          existingUpdatedAt >= newUpdatedAt
        {
          mergedTracks.append(existingTrack)
        } else {
          newTrack.localFilePath = existingTrack.localFilePath
          mergedTracks.append(newTrack)
        }
      } else {
        mergedTracks.append(newTrack)
      }
    }

    self.audioTracks = mergedTracks
  }
}
