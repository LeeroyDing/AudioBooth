import API
import SwiftUI

@main
struct AudioBSWatch: App {
  init() {
    DownloadManager.shared.cleanupOrphanedDownloads()
    _ = Audiobookshelf.shared
    _ = WatchConnectivityManager.shared
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
