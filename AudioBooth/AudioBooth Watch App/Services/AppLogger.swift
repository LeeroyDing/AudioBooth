import OSLog

enum AppLogger {
  private static let subsystem = Bundle.main.bundleIdentifier ?? "me.jgrenier.AudioBS.watchkitapp"

  static let watchConnectivity = Logger(subsystem: subsystem, category: "watch-connectivity")
  static let player = Logger(subsystem: subsystem, category: "player")
  static let download = Logger(subsystem: subsystem, category: "download")
  static let viewModel = Logger(subsystem: subsystem, category: "viewModel")
  static let general = Logger(subsystem: subsystem, category: "general")
}
