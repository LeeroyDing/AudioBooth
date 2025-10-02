import Audiobookshelf
import Combine
import Models
import SwiftUI

struct ContentView: View {
  @ObservedObject var connectivityManager = WatchConnectivityManager.shared
  @ObservedObject var playerManager = PlayerManager.shared

  @StateObject private var model: Model = Model()

  var body: some View {
    if Audiobookshelf.shared.authentication.connection == nil {
      VStack {
        ProgressView()
          .controlSize(.large)
        Text("Authenticating...")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.top, 8)
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
    if let localPlayer = playerManager.current {
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
    } else if connectivityManager.hasActivePlayer {
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
    }
  }
}

extension ContentView {
  @Observable
  class Model: ObservableObject {
    var player: PlayerView.Model?
  }
}

#Preview {
  ContentView()
}
