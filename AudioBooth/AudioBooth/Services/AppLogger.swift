import OSLog

enum AppLogger {
  private static let subsystem = Bundle.main.bundleIdentifier ?? "me.jgrenier.AudioBS"

  static let session = Logger(subsystem: subsystem, category: "session")
  static let network = Logger(subsystem: subsystem, category: "network")
  static let watchConnectivity = Logger(subsystem: subsystem, category: "watch-connectivity")
  static let player = Logger(subsystem: subsystem, category: "player")
  static let download = Logger(subsystem: subsystem, category: "download")
  static let viewModel = Logger(subsystem: subsystem, category: "viewModel")
  static let persistence = Logger(subsystem: subsystem, category: "persistence")
  static let general = Logger(subsystem: subsystem, category: "general")
  static let authentication = Logger(subsystem: subsystem, category: "authentication")
}
