import Foundation
import OSLog

enum LogExporter {
  static func exportLogs(since: TimeInterval = 3600) async throws -> URL {
    let subsystem = Bundle.main.bundleIdentifier ?? "me.jgrenier.AudioBS"
    let logStore = try OSLogStore(scope: .currentProcessIdentifier)
    let sinceDate = Date.now.addingTimeInterval(-since)
    let position = logStore.position(date: sinceDate)

    let entries = try logStore.getEntries(at: position)
      .compactMap { $0 as? OSLogEntryLog }
      .filter { $0.subsystem == subsystem }

    var logText = "AudioBooth Log Export\n"
    logText += "Generated: \(Date.now.formatted())\n"
    logText += "Period: Last \(Int(since / 60)) minutes\n"
    logText += "Subsystem: \(subsystem)\n"
    logText += String(repeating: "=", count: 80) + "\n\n"

    for entry in entries {
      let timestamp = entry.date.formatted(date: .omitted, time: .standard)
      let level = entry.level.description
      let category = entry.category
      let message = entry.composedMessage

      logText += "[\(timestamp)] [\(level)] [\(category)] \(message)\n"
    }

    // Use a temporary file with proper UTI
    let tempDirectory = FileManager.default.temporaryDirectory
    let fileName = "audiobooth-logs-\(Int(Date.now.timeIntervalSince1970)).txt"
    let fileURL = tempDirectory.appendingPathComponent(fileName)

    try logText.write(to: fileURL, atomically: true, encoding: .utf8)

    return fileURL
  }
}

extension OSLogEntryLog.Level {
  var description: String {
    switch self {
    case .undefined: return "UNDEFINED"
    case .debug: return "DEBUG"
    case .info: return "INFO"
    case .notice: return "NOTICE"
    case .error: return "ERROR"
    case .fault: return "FAULT"
    @unknown default: return "UNKNOWN"
    }
  }
}
