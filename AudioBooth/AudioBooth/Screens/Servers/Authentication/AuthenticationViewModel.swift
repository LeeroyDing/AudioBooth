import API
import Foundation
import Logging

final class AuthenticationViewModel: AuthenticationView.Model {
  private let audiobookshelf = Audiobookshelf.shared
  private let server: Server
  private var oidcAuthManager: OIDCAuthenticationManager?

  init(server: Server) {
    self.server = server
    super.init()
  }

  override func onLoginTapped() {
    guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      return
    }

    isLoading = true

    Task {
      do {
        _ = try await audiobookshelf.authentication.login(
          serverURL: server.baseURL.absoluteString,
          username: username.trimmingCharacters(in: .whitespacesAndNewlines),
          password: password,
          customHeaders: server.customHeaders
        )
        password = ""
        onAuthenticationSuccess()
      } catch {
        AppLogger.viewModel.error("Re-authentication failed: \(error.localizedDescription)")
        Toast(error: error.localizedDescription).show()
      }

      isLoading = false
    }
  }

  override func onOIDCLoginTapped() {
    isLoading = true

    let authManager = OIDCAuthenticationManager(
      serverURL: server.baseURL.absoluteString,
      customHeaders: server.customHeaders
    )
    authManager.delegate = self
    self.oidcAuthManager = authManager

    authManager.start()
  }

  func showError(_ message: String) {
    Toast(error: message).show()
    isLoading = false
  }
}

extension AuthenticationViewModel: OIDCAuthenticationDelegate {
  func oidcAuthenticationDidSucceed(connectionID: String) {
    isLoading = false
    oidcAuthManager = nil
    Toast(success: "Successfully authenticated with SSO").show()
    onAuthenticationSuccess()
  }

  func oidcAuthentication(didFailWithError error: Error) {
    showError("SSO login failed: \(error.localizedDescription)")
    isLoading = false
    oidcAuthManager = nil
  }
}
