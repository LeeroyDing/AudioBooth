import Foundation
import SwiftUI

enum NavigationDestination: Hashable {
  case book(id: String)
  case series(id: String, name: String)
  case author(id: String, name: String)
}

private struct NavigationPathKey: EnvironmentKey {
  static let defaultValue: Binding<NavigationPath>? = nil
}

extension EnvironmentValues {
  var navigationPath: Binding<NavigationPath>? {
    get { self[NavigationPathKey.self] }
    set { self[NavigationPathKey.self] = newValue }
  }
}
