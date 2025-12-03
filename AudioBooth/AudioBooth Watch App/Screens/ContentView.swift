import API
import Combine
import Models
import SwiftUI

struct ContentView: View {
  @ObservedObject var connectivityManager = WatchConnectivityManager.shared
  @ObservedObject var playerManager = PlayerManager.shared
  @ObservedObject var libraries = Audiobookshelf.shared.libraries

  @StateObject private var model: Model = ContentViewModel()

  var body: some View {
    if Audiobookshelf.shared.authentication.server == nil || libraries.current == nil {
      VStack(spacing: 16) {
        if !model.authTimeout {
          ProgressView()
            .controlSize(.large)
          Text("Authenticating...")
            .font(.caption)
            .foregroundColor(.secondary)
        } else {
          Image(systemName: "exclamationmark.triangle")
            .font(.largeTitle)
            .foregroundColor(.orange)

          Text("Authentication Timeout")
            .font(.caption)
            .fontWeight(.medium)

          Text("Make sure your iPhone is nearby and the app is open")
            .font(.caption2)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

          Button("Retry", action: model.retryAuth)
            .buttonStyle(.borderedProminent)
        }
      }
      .task {
        await model.onAuthenticationWait()
      }
    } else {
      NavigationStack {
        ContinueListeningView(model: ContinueListeningViewModel())
          .toolbar {
            toolbar
          }
          .sheet(item: $model.player) { model in
            PlayerView(model: model)
          }
          .onChange(of: playerManager.isShowingFullPlayer) { _, newValue in
            guard newValue, let model = playerManager.current else { return }
            self.model.player = model
          }
      }
    }
  }

  @ToolbarContentBuilder
  var toolbar: some ToolbarContent {
    if connectivityManager.hasActivePlayer
      && !playerManager.isPlayingLocally
      && !connectivityManager.bookID.isEmpty
    {
      ToolbarItem(placement: .topBarTrailing) {
        Button(
          action: {
            model.player = RemotePlayerModel()
          },
          label: {
            Image(systemName: "iphone")
          }
        )
      }
    } else if let localPlayer = playerManager.current {
      ToolbarItem(placement: .topBarTrailing) {
        Button(
          action: {
            model.player = localPlayer
          },
          label: {
            Image(systemName: "applewatch")
          }
        )
      }
    }
  }
}

extension ContentView {
  @Observable
  class Model: ObservableObject {
    var player: PlayerView.Model?
    var authTimeout: Bool

    func onAuthenticationWait() async {}
    func retryAuth() {}

    init(player: PlayerView.Model? = nil, authTimeout: Bool = false) {
      self.player = player
      self.authTimeout = authTimeout
    }
  }
}

#Preview {
  ContentView()
}
