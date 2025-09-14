import Combine
import SwiftUI

@MainActor
final class AppStateManager: ObservableObject {
  static let shared = AppStateManager()

  @Published private(set) var isInBackground = false

  private init() {}

  func updateScenePhase(_ scenePhase: ScenePhase) {
    switch scenePhase {
    case .active:
      isInBackground = false
    case .inactive, .background:
      isInBackground = true
    @unknown default:
      break
    }
  }
}
