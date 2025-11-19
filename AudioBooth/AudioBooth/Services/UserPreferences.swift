import Combine
import Foundation
import Models
import SwiftUI

final class UserPreferences: ObservableObject {
  static let shared = UserPreferences()

  @AppStorage("skipForwardInterval") var skipForwardInterval: Double = 30.0
  @AppStorage("skipBackwardInterval") var skipBackwardInterval: Double = 30.0
  @AppStorage("smartRewindInterval") var smartRewindInterval: Double = 30.0
  @AppStorage("showListeningStats") var showListeningStats: Bool = false
  @AppStorage("showDebugSection") var showDebugSection: Bool = false
  @AppStorage("libraryDisplayMode") var libraryDisplayMode: BookCard.DisplayMode = .card
  @AppStorage("autoDownloadBooks") var autoDownloadBooks: Bool = false
  @AppStorage("removeDownloadOnCompletion") var removeDownloadOnCompletion: Bool = false

  private init() {}
}
