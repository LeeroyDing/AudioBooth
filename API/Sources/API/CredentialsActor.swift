import Foundation

actor CredentialsActor {
  private var refreshTask: Task<Credentials, Error>?
  private weak var server: Server?

  init(server: Server) {
    self.server = server
  }

  var freshCredentials: Credentials {
    get async throws {
      guard let server = server else {
        throw Audiobookshelf.AudiobookshelfError.networkError("No server")
      }

      guard case .bearer(_, _, let expiresAt) = server.token else {
        return server.token
      }

      let currentTime = Date().timeIntervalSince1970
      let bufferTime: TimeInterval = 60

      if currentTime < (expiresAt - bufferTime) {
        return server.token
      }

      if let refreshTask {
        return try await refreshTask.value
      }

      let task = Task<Credentials, Error> { @MainActor [server] in
        try await Audiobookshelf.shared.authentication.refreshToken(for: server)
        return server.token
      }

      refreshTask = task

      do {
        let credentials = try await task.value
        refreshTask = nil
        return credentials
      } catch {
        refreshTask = nil
        throw error
      }
    }
  }
}
