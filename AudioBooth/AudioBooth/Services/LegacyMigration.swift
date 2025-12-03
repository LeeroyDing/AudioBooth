import API
import Foundation
import Logging
import Models
import SwiftData

struct LegacyMigration {
  static func migrateIfNeeded() {
    migration0()
    migration1()
  }

  static func migrateTrackPaths() {
    migration2()
  }

  private static func migration0() {
    let fileManager = FileManager.default

    guard
      let appGroupURL = fileManager.containerURL(
        forSecurityApplicationGroupIdentifier: "group.me.jgrenier.audioBS"
      )
    else {
      return
    }

    let legacyDBURL = appGroupURL.appending(path: "AudiobookshelfData.sqlite")

    guard fileManager.fileExists(atPath: legacyDBURL.path),
      let serverID = Audiobookshelf.shared.authentication.server?.id
    else {
      return
    }

    AppLogger.persistence.info("Migration 0: App group root → per-server structure")

    let serverDir = appGroupURL.appending(path: serverID)
    try? fileManager.createDirectory(at: serverDir, withIntermediateDirectories: true)

    let newDBURL = serverDir.appending(path: "AudiobookshelfData.sqlite")
    let extensions = ["", "-shm", "-wal"]

    for ext in extensions {
      let sourceURL = URL(fileURLWithPath: legacyDBURL.path + ext)
      let destURL = URL(fileURLWithPath: newDBURL.path + ext)

      if fileManager.fileExists(atPath: sourceURL.path),
        !fileManager.fileExists(atPath: destURL.path)
      {
        try? fileManager.moveItem(at: sourceURL, to: destURL)
      }
    }

    let legacyAudiobooksURL = appGroupURL.appending(path: "audiobooks")
    let newAudiobooksURL = serverDir.appending(path: "audiobooks")

    if fileManager.fileExists(atPath: legacyAudiobooksURL.path),
      !fileManager.fileExists(atPath: newAudiobooksURL.path)
    {
      try? fileManager.moveItem(at: legacyAudiobooksURL, to: newAudiobooksURL)
    }
  }

  private static func migration1() {
    let fileManager = FileManager.default

    guard
      let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
      let appGroupURL = fileManager.containerURL(
        forSecurityApplicationGroupIdentifier: "group.me.jgrenier.audioBS"
      )
    else {
      return
    }

    let legacyDBURL = documentsURL.appending(path: "AudiobookshelfData.sqlite")

    guard fileManager.fileExists(atPath: legacyDBURL.path),
      let serverID = Audiobookshelf.shared.authentication.server?.id
    else {
      return
    }

    AppLogger.persistence.info("Migration 1: Documents → per-server structure")

    let serverDir = appGroupURL.appending(path: serverID)
    try? fileManager.createDirectory(at: serverDir, withIntermediateDirectories: true)

    let newDBURL = serverDir.appending(path: "AudiobookshelfData.sqlite")
    let extensions = ["", "-shm", "-wal"]

    for ext in extensions {
      let sourceURL = URL(fileURLWithPath: legacyDBURL.path + ext)
      let destURL = URL(fileURLWithPath: newDBURL.path + ext)

      if fileManager.fileExists(atPath: sourceURL.path),
        !fileManager.fileExists(atPath: destURL.path)
      {
        try? fileManager.moveItem(at: sourceURL, to: destURL)
      }
    }

    let legacyAudiobooksURL = documentsURL.appending(path: "audiobooks")
    let newAudiobooksURL = serverDir.appending(path: "audiobooks")

    if fileManager.fileExists(atPath: legacyAudiobooksURL.path),
      !fileManager.fileExists(atPath: newAudiobooksURL.path)
    {
      try? fileManager.moveItem(at: legacyAudiobooksURL, to: newAudiobooksURL)
    }
  }

  private static func migration2() {
    guard let serverID = Audiobookshelf.shared.authentication.server?.id,
      let context = ModelContextProvider.shared.container?.mainContext
    else {
      return
    }

    let descriptor = FetchDescriptor<LocalBook>()
    guard let books = try? context.fetch(descriptor) else {
      return
    }

    var migratedCount = 0
    for book in books {
      for track in book.tracks {
        if let relativePath = track.relativePath,
          relativePath.relativePath.hasPrefix("audiobooks/")
        {
          let newPath = "\(serverID)/\(relativePath.relativePath)"
          track.relativePath = URL(string: newPath)
          migratedCount += 1
        }
      }
    }

    if migratedCount > 0 {
      try? context.save()
      AppLogger.persistence.info(
        "Migration 2: Updated \(migratedCount) track paths to include server ID")
    }
  }
}
