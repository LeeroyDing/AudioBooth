import Foundation

enum NavigationDestination: Hashable {
  case book(id: String)
  case series(id: String, name: String)
  case author(id: String, name: String)
}
