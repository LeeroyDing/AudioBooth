import Audiobookshelf
import Foundation
import SwiftData

@Model
final class MediaProgress {
  @Attribute(.unique) var bookID: String
  var id: String?
  var lastPlayedAt: Date
  var currentTime: TimeInterval
  var timeListened: TimeInterval
  var duration: TimeInterval
  var progress: Double
  var isFinished: Bool
  var lastUpdate: Date

  init(
    bookID: String,
    id: String? = nil,
    lastPlayedAt: Date = Date(),
    currentTime: TimeInterval = 0,
    timeListened: TimeInterval = 0,
    duration: TimeInterval = 0,
    progress: Double = 0,
    isFinished: Bool = false,
    lastUpdate: Date = Date()
  ) {
    self.bookID = bookID
    self.id = id
    self.lastPlayedAt = lastPlayedAt
    self.currentTime = currentTime
    self.timeListened = timeListened
    self.duration = duration
    self.progress = progress
    self.isFinished = isFinished
    self.lastUpdate = lastUpdate
  }

  convenience init(from apiProgress: User.MediaProgress, duration: TimeInterval = 0) {
    self.init(
      bookID: apiProgress.libraryItemId,
      id: apiProgress.id,
      lastPlayedAt: Date(timeIntervalSince1970: TimeInterval(apiProgress.lastUpdate / 1000)),
      currentTime: apiProgress.currentTime,
      timeListened: 0,
      duration: duration,
      progress: apiProgress.progress,
      isFinished: apiProgress.progress >= 1.0,
      lastUpdate: Date(timeIntervalSince1970: TimeInterval(apiProgress.lastUpdate / 1000))
    )
  }
}

extension MediaProgress {
  @MainActor
  static func fetchAll() throws -> [MediaProgress] {
    let context = ModelContextProvider.shared.context
    let descriptor = FetchDescriptor<MediaProgress>(
      sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
    )
    let results = try context.fetch(descriptor)
    return results
  }

  @MainActor
  static func observe(bookID: String) -> AsyncStream<MediaProgress?> {
    AsyncStream { continuation in
      let context = ModelContextProvider.shared.context
      let predicate = #Predicate<MediaProgress> { progress in
        progress.bookID == bookID
      }
      let descriptor = FetchDescriptor<MediaProgress>(predicate: predicate)

      let fetchData = {
        do {
          let results = try context.fetch(descriptor)
          continuation.yield(results.first)
        } catch {
          continuation.yield(nil)
        }
      }

      fetchData()

      let observer = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave,
        object: context,
        queue: .main
      ) { _ in
        fetchData()
      }

      continuation.onTermination = { _ in
        NotificationCenter.default.removeObserver(observer)
      }
    }
  }

  @MainActor
  static func fetch(bookID: String) throws -> MediaProgress? {
    let context = ModelContextProvider.shared.context
    let predicate = #Predicate<MediaProgress> { progress in
      progress.bookID == bookID
    }
    let descriptor = FetchDescriptor<MediaProgress>(predicate: predicate)
    let results = try context.fetch(descriptor)

    return results.first
  }

  @MainActor
  func save() throws {
    let context = ModelContextProvider.shared.context

    if let existingProgress = try MediaProgress.fetch(bookID: self.bookID) {
      existingProgress.id = self.id
      existingProgress.lastPlayedAt = self.lastPlayedAt
      existingProgress.currentTime = self.currentTime
      existingProgress.timeListened = self.timeListened
      existingProgress.duration = self.duration
      existingProgress.progress = self.progress
      existingProgress.isFinished = self.isFinished
      existingProgress.lastUpdate = self.lastUpdate
    } else {
      context.insert(self)
    }

    try context.save()
  }

  @MainActor
  func delete() throws {
    let context = ModelContextProvider.shared.context
    context.delete(self)
    try context.save()
  }

  @MainActor
  static func deleteAll() throws {
    let context = ModelContextProvider.shared.context
    let descriptor = FetchDescriptor<MediaProgress>()
    let allProgress = try context.fetch(descriptor)

    for progress in allProgress {
      context.delete(progress)
    }

    try context.save()
  }

  @MainActor
  static func getOrCreate(for bookID: String, duration: TimeInterval = 0) throws -> MediaProgress {
    if let existingProgress = try MediaProgress.fetch(bookID: bookID) {
      return existingProgress
    } else {
      let newProgress = MediaProgress(
        bookID: bookID,
        id: nil,
        duration: duration
      )
      try newProgress.save()
      return newProgress
    }
  }

  @MainActor
  static func updateProgress(
    for bookID: String,
    currentTime: TimeInterval,
    timeListened: TimeInterval,
    duration: TimeInterval,
    progress: Double
  ) throws {
    if let existingProgress = try MediaProgress.fetch(bookID: bookID) {
      existingProgress.currentTime = currentTime
      existingProgress.timeListened = timeListened
      existingProgress.duration = duration
      existingProgress.progress = progress
      existingProgress.lastPlayedAt = Date()
      existingProgress.lastUpdate = Date()
      existingProgress.isFinished = progress >= 1.0
      try existingProgress.save()
    } else {
      let newProgress = MediaProgress(
        bookID: bookID,
        id: nil,
        lastPlayedAt: Date(),
        currentTime: currentTime,
        timeListened: timeListened,
        duration: duration,
        progress: progress,
        isFinished: progress >= 1.0,
        lastUpdate: Date()
      )
      try newProgress.save()
    }
  }

  @MainActor
  static func updateFinishedStatus(for bookID: String, isFinished: Bool) throws {
    if isFinished {
      if let existingProgress = try MediaProgress.fetch(bookID: bookID) {
        existingProgress.progress = 1.0
        existingProgress.isFinished = true
        existingProgress.lastUpdate = Date()
        try existingProgress.save()
      }
    } else {
      if let existingProgress = try MediaProgress.fetch(bookID: bookID) {
        try existingProgress.delete()
      }
    }
  }

  @MainActor
  static func syncFromAPI() async throws {
    let userData = try await Audiobookshelf.shared.authentication.fetchMe()

    let context = ModelContextProvider.shared.context

    for apiProgress in userData.mediaProgress {
      let localProgress = MediaProgress(from: apiProgress)

      if let existingProgress = try MediaProgress.fetch(bookID: apiProgress.libraryItemId) {
        existingProgress.id = localProgress.id

        if localProgress.lastUpdate > existingProgress.lastUpdate {
          existingProgress.lastPlayedAt = localProgress.lastPlayedAt
          existingProgress.currentTime = localProgress.currentTime
          existingProgress.timeListened = localProgress.timeListened
          existingProgress.duration = localProgress.duration
          existingProgress.progress = localProgress.progress
          existingProgress.isFinished = localProgress.isFinished
          existingProgress.lastUpdate = localProgress.lastUpdate
        }
      } else {
        context.insert(localProgress)
      }
    }

    try context.save()
  }
}
