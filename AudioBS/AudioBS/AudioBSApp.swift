import Audiobookshelf
import SwiftUI

@main
struct AudioBSApp: App {
  init() {
    DownloadManager.shared.cleanupOrphanedDownloads()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
