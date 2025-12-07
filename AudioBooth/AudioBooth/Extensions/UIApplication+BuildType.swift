import UIKit

extension UIApplication {
  private static let isTestFlight =
    Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"

  public static var isDebug: Bool {
    #if DEBUG
    return true
    #else
    return false
    #endif
  }

  public enum BuildType {
    case debug
    case testFlight
    case appStore
  }

  public static var buildType: BuildType {
    if isDebug {
      return .debug
    } else if isTestFlight {
      return .testFlight
    } else {
      return .appStore
    }
  }
}
