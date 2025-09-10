import Foundation

public final class SessionService {
  private let audiobookshelf: Audiobookshelf

  init(audiobookshelf: Audiobookshelf) {
    self.audiobookshelf = audiobookshelf
  }

  public func start(
    itemID: String, forceDirectPlay: Bool = false, forceTranscode: Bool = false
  ) async throws -> PlaySession {
    guard let networkService = audiobookshelf.networkService,
      let serverURL = audiobookshelf.serverURL
    else {
      throw Audiobookshelf.AudiobookshelfError.networkError(
        "Network service not configured. Please login first.")
    }

    struct PlayRequest: Codable {
      let forceDirectPlay: Bool
      let forceTranscode: Bool
      let supportedMimeTypes: [String]
      let mediaPlayer: String
      let deviceInfo: DeviceInfo

      struct DeviceInfo: Codable {
        let clientName: String
        let deviceId: String
      }

      init(forceDirectPlay: Bool, forceTranscode: Bool) {
        self.forceDirectPlay = forceDirectPlay
        self.forceTranscode = forceTranscode
        self.supportedMimeTypes = [
          "audio/flac", "audio/mpeg", "audio/mp4", "audio/ogg", "audio/aac", "audio/x-aiff",
          "audio/webm",
        ]
        self.mediaPlayer = "ios-app"
        self.deviceInfo = DeviceInfo(clientName: "Abs iOS", deviceId: UUID().uuidString)
      }
    }

    let request = NetworkRequest<PlaySession>(
      path: "/api/items/\(itemID)/play",
      method: .post,
      body: PlayRequest(forceDirectPlay: forceDirectPlay, forceTranscode: false),
      timeout: 3
    )

    do {
      let response = try await networkService.send(request)
      var session = response.value
      session.setServerURL(serverURL)
      return session
    } catch {
      throw Audiobookshelf.AudiobookshelfError.networkError(
        "Failed to start play session: \(error.localizedDescription)")
    }
  }

  public func sync(_ id: String, timeListened: Double, currentTime: Double) async throws {
    guard let networkService = audiobookshelf.networkService else {
      throw Audiobookshelf.AudiobookshelfError.networkError(
        "Network service not configured. Please login first.")
    }

    struct SyncRequest: Codable {
      let timeListened: Int
      let currentTime: Double
    }

    let request = NetworkRequest<Data>(
      path: "/api/session/\(id)/sync",
      method: .post,
      body: SyncRequest(timeListened: Int(timeListened), currentTime: currentTime),
      timeout: 3
    )

    do {
      _ = try await networkService.send(request)
    } catch {
      throw Audiobookshelf.AudiobookshelfError.networkError(
        "Failed to sync session: \(error.localizedDescription)")
    }
  }

  public func stop(_ id: String) async throws {
    guard let networkService = audiobookshelf.networkService else {
      throw Audiobookshelf.AudiobookshelfError.networkError(
        "Network service not configured. Please login first.")
    }

    struct Response: Codable {}

    let request = NetworkRequest<Response>(
      path: "/api/session/\(id)",
      method: .delete
    )

    do {
      _ = try await networkService.send(request)
    } catch {
      throw Audiobookshelf.AudiobookshelfError.networkError(
        "Failed to stop play session: \(error.localizedDescription)")
    }
  }

  public func removeFromContinueListening(_ progressID: String) async throws {
    guard let networkService = audiobookshelf.networkService else {
      throw Audiobookshelf.AudiobookshelfError.networkError(
        "Network service not configured. Please login first.")
    }

    struct Response: Codable {}

    let request = NetworkRequest<Response>(
      path: "/api/me/progress/\(progressID)/remove-from-continue-listening",
      method: .get
    )

    do {
      _ = try await networkService.send(request)
    } catch {
      throw Audiobookshelf.AudiobookshelfError.networkError(
        "Failed to remove from continue listening: \(error.localizedDescription)")
    }
  }
}
