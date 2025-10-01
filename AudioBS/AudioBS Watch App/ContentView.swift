import SwiftUI

struct ContentView: View {
  @ObservedObject var connectivityManager = WatchConnectivityManager.shared

  var body: some View {
    NavigationStack {
      if connectivityManager.hasActivePlayer {
        NowPlayingView()
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              NavigationLink {
                RecentlyPlayedListView()
              } label: {
                Image(systemName: "list.bullet")
              }
            }
          }
      } else {
        List {
          if connectivityManager.recentlyPlayed.isEmpty {
            VStack(spacing: 16) {
              Image(systemName: "headphones")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

              Text("No Active Playback")
                .font(.headline)

              Text("Start playing on your iPhone")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
          } else {
            NavigationLink {
              RecentlyPlayedListView()
            } label: {
              Label("Recently Played", systemImage: "clock")
            }
          }
        }
        .navigationTitle("AudioBS")
      }
    }
  }
}

#Preview {
  ContentView()
}
