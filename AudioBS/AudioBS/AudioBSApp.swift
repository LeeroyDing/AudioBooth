import API
import RevenueCat
import SwiftUI
import UIKit

@main
struct AudioBSApp: App {
  init() {
    DownloadManager.shared.cleanupOrphanedDownloads()
    _ = WatchConnectivityManager.shared

    Audiobookshelf.shared.authentication.onAuthenticationChanged = { credentials in
      if let (serverURL, token) = credentials {
        WatchConnectivityManager.shared.syncAuthCredentials(serverURL: serverURL, token: token)
      } else {
        WatchConnectivityManager.shared.clearAuthCredentials()
      }
    }

    Audiobookshelf.shared.libraries.onLibraryChanged = { library in
      if let library {
        WatchConnectivityManager.shared.syncLibrary(library)
      } else {
        WatchConnectivityManager.shared.clearLibrary()
      }
    }

    if let connection = Audiobookshelf.shared.authentication.connection {
      WatchConnectivityManager.shared.syncAuthCredentials(
        serverURL: connection.serverURL, token: connection.token)
    }

    if let library = Audiobookshelf.shared.libraries.current {
      WatchConnectivityManager.shared.syncLibrary(library)
    }

    Purchases.logLevel = .error
    Purchases.configure(withAPIKey: "appl_AuBdFKRrOngbJsXGkkxDKGNbGRW")
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
