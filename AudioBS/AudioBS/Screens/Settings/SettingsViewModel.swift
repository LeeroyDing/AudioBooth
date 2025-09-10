import Audiobookshelf
import SwiftUI

@MainActor
final class SettingsViewModel: SettingsView.Model {
  private let audiobookshelf = Audiobookshelf.shared

  init() {
    let isAuthenticated = audiobookshelf.isAuthenticated
    let serverURL = audiobookshelf.serverURL?.absoluteString ?? ""

    super.init(
      isAuthenticated: isAuthenticated,
      serverURL: serverURL,
      username: "",
      password: "",
      library: LibrariesViewModel()
    )
  }

  override func onLoginTapped() {
    guard !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      return
    }

    isLoading = true
    let normalizedURL = normalizeServerURL(
      serverURL.trimmingCharacters(in: .whitespacesAndNewlines))
    serverURL = normalizedURL

    Task {
      do {
        try await audiobookshelf.authentication.login(
          serverURL: normalizedURL,
          username: username.trimmingCharacters(in: .whitespacesAndNewlines),
          password: password
        )
        password = ""
        isAuthenticated = true
        navigationPath.append("libraries")
      } catch {
        print("Login failed: \(error.localizedDescription)")
        ToastManager.shared.show(error: "Login failed: \(error.localizedDescription)")
        isAuthenticated = false
      }

      isLoading = false
    }
  }

  override func onClearStorageTapped() {
    Task {
      do {
        try RecentlyPlayedItem.deleteAll()
        PlayerManager.shared.clearCurrent()
        ToastManager.shared.show(success: "Storage cleared successfully")
      } catch {
        print("Failed to clear storage: \(error.localizedDescription)")
        ToastManager.shared.show(error: "Failed to clear storage: \(error.localizedDescription)")
      }
    }
  }

  override func onDiscoverServersTapped() {
    isDiscovering = true
    discoveredServers = []

    Task {
      let port = Int(discoveryPort) ?? 13378
      let servers = await audiobookshelf.networkDiscovery.discoverServers(port: port)
      discoveredServers = servers

      isDiscovering = false
    }
  }

  override func onServerSelected(_ server: DiscoveredServer) {
    serverURL = server.serverURL.absoluteString
  }

  override func onLogoutTapped() {
    audiobookshelf.logout()

    isAuthenticated = false
    username = ""
    password = ""
    discoveredServers = []
    library = LibrariesViewModel()
  }

  private func normalizeServerURL(_ url: String) -> String {
    let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmedURL.hasPrefix("http://") || trimmedURL.hasPrefix("https://") {
      return trimmedURL
    } else {
      return "http://" + trimmedURL
    }
  }
}
