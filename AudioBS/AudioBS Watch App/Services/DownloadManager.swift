import API
import AVFoundation
import Combine
import Foundation
import Models
import SwiftData

final class DownloadManager: NSObject, ObservableObject {
  static let shared = DownloadManager()

  enum DownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
  }

  private let operationQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    queue.name = "me.jgrenier.AudioBS.watch.downloadQueue"
    return queue
  }()

  private var activeOperations: [String: DownloadOperation] = [:]
  private var progressTasks: [String: Task<Void, Never>] = [:]
  @Published private(set) var currentProgress: [String: Double] = [:]

  func isDownloading(for bookID: String) -> Bool {
    activeOperations[bookID] != nil
  }

  func startDownload(for item: LocalBook, session: Session) {
    guard activeOperations[item.bookID] == nil else { return }

    let operation = DownloadOperation(book: item, session: session)
    activeOperations[item.bookID] = operation
    currentProgress.removeValue(forKey: item.bookID)

    let progressTask = Task { @MainActor [weak self] in
      for await progress in operation.progress {
        guard !Task.isCancelled else { break }
        self?.currentProgress[item.bookID] = progress
      }
    }
    progressTasks[item.bookID] = progressTask

    operation.completionBlock = { @MainActor [weak self] in
      self?.progressTasks[item.bookID]?.cancel()
      self?.progressTasks.removeValue(forKey: item.bookID)
      self?.activeOperations.removeValue(forKey: item.bookID)
      self?.currentProgress.removeValue(forKey: item.bookID)
    }

    operationQueue.addOperation(operation)
  }

  func startDownload(for book: LocalBook) {
    guard activeOperations[book.bookID] == nil else { return }

    let operation = DownloadOperation(bookID: book.bookID)
    activeOperations[book.bookID] = operation
    currentProgress.removeValue(forKey: book.bookID)

    let progressTask = Task { @MainActor [weak self] in
      for await progress in operation.progress {
        guard !Task.isCancelled else { break }
        self?.currentProgress[book.bookID] = progress
      }
    }
    progressTasks[book.bookID] = progressTask

    operation.completionBlock = { @MainActor [weak self] in
      self?.progressTasks[book.bookID]?.cancel()
      self?.progressTasks.removeValue(forKey: book.bookID)
      self?.activeOperations.removeValue(forKey: book.bookID)
      self?.currentProgress.removeValue(forKey: book.bookID)
    }

    operationQueue.addOperation(operation)
  }

  func cancelDownload(for bookID: String) {
    activeOperations[bookID]?.cancel()
  }
}

extension DownloadManager {
  func deleteDownload(for bookID: String) {
    Task {
      let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        .first!
      let bookDirectory = documentsPath.appendingPathComponent("audiobooks").appendingPathComponent(
        bookID)

      do {
        if FileManager.default.fileExists(atPath: bookDirectory.path) {
          try FileManager.default.removeItem(at: bookDirectory)
        }

        if let item = try? LocalBook.fetch(bookID: bookID) {
          for track in item.orderedTracks {
            track.relativePath = nil
          }
          try? item.save()
        }
      } catch {
        print("Failed to delete download: \(error.localizedDescription)")
      }
    }
  }

  func cleanupOrphanedDownloads() {
    Task {
      do {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
          .first!
        let audiobooksDirectory = documentsPath.appendingPathComponent("audiobooks")

        guard FileManager.default.fileExists(atPath: audiobooksDirectory.path) else {
          print("Audiobooks directory does not exist, nothing to cleanup")
          return
        }

        var orphanedFilesCount = 0
        var orphanedDirectoriesCount = 0

        let downloadDirectories = try FileManager.default.contentsOfDirectory(
          at: audiobooksDirectory, includingPropertiesForKeys: [.isDirectoryKey])

        for directory in downloadDirectories {
          var isDirectory: ObjCBool = false
          FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory)

          if isDirectory.boolValue {
            let bookID = directory.lastPathComponent

            guard let item = try? LocalBook.fetch(bookID: bookID) else {
              try FileManager.default.removeItem(at: directory)
              orphanedDirectoriesCount += 1
              print("Removed orphaned directory for unknown book: \(bookID)")
              continue
            }

            let tracks = item.orderedTracks

            var expectedFilenames = Set<String>()
            for track in tracks {
              if let relativePath = track.relativePath {
                expectedFilenames.insert(relativePath.lastPathComponent)
              }
            }

            let filesInDirectory = try FileManager.default.contentsOfDirectory(
              at: directory, includingPropertiesForKeys: nil)

            for file in filesInDirectory {
              let filename = file.lastPathComponent

              if !expectedFilenames.contains(filename) {
                try FileManager.default.removeItem(at: file)
                orphanedFilesCount += 1
              }
            }

            let remainingFiles = try FileManager.default.contentsOfDirectory(
              at: directory, includingPropertiesForKeys: nil)
            if remainingFiles.isEmpty {
              try FileManager.default.removeItem(at: directory)
              orphanedDirectoriesCount += 1
            }
          }
        }

      } catch {
      }
    }
  }

}

private final class DownloadOperation: Operation, @unchecked Sendable {
  private var audiobookshelf: Audiobookshelf { .shared }

  let bookID: String
  let progress: AsyncStream<Double>

  private let progressContinuation: AsyncStream<Double>.Continuation

  private var book: LocalBook?
  private var session: Session?
  private var totalBytes: Int64 = 0
  private var bytesDownloadedSoFar: Int64 = 0

  private var currentTrack: URLSessionDownloadTask?
  private var continuation: CheckedContinuation<Void, Error>?
  private var trackDestination: URL?

  private lazy var downloadSession: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 60
    config.timeoutIntervalForResource = 3600
    config.allowsCellularAccess = true
    config.waitsForConnectivity = true
    config.allowsExpensiveNetworkAccess = true
    config.allowsConstrainedNetworkAccess = true
    return URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }()

  private var _executing = false {
    willSet {
      willChangeValue(forKey: "isExecuting")
    }
    didSet {
      didChangeValue(forKey: "isExecuting")
    }
  }

  private var _finished = false {
    willSet {
      willChangeValue(forKey: "isFinished")
    }
    didSet {
      didChangeValue(forKey: "isFinished")
    }
  }

  override var isAsynchronous: Bool { true }
  override var isExecuting: Bool { _executing }
  override var isFinished: Bool { _finished }

  init(bookID: String) {
    self.bookID = bookID

    let (stream, continuation) = AsyncStream.makeStream(
      of: Double.self, bufferingPolicy: .bufferingNewest(1))
    self.progress = stream
    self.progressContinuation = continuation

    super.init()
  }

  init(book: LocalBook, session: Session) {
    self.bookID = book.bookID
    self.book = book
    self.session = session

    let (stream, continuation) = AsyncStream.makeStream(
      of: Double.self, bufferingPolicy: .bufferingNewest(1))
    self.progress = stream
    self.progressContinuation = continuation

    super.init()
  }

  override func start() {
    guard !isCancelled else {
      finish(success: false, error: CancellationError())
      return
    }

    _executing = true

    Task {
      await executeDownload()
    }
  }

  override func cancel() {
    super.cancel()
    currentTrack?.cancel()
    progressContinuation.finish()

    Task {
      await cleanupPartialDownload()
    }
  }

  private func cleanupPartialDownload() async {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
      .first!
    let bookDirectory = documentsPath.appendingPathComponent("audiobooks").appendingPathComponent(
      bookID)
    try? FileManager.default.removeItem(at: bookDirectory)
  }

  private func executeDownload() async {
    do {
      if book == nil || session == nil {
        let playSession = try await audiobookshelf.sessions.start(
          itemID: bookID,
          isDownload: true
        )

        guard !isCancelled else {
          finish(success: false, error: CancellationError())
          return
        }

        guard let session = Session(from: playSession) else {
          finish(success: false, error: URLError(.badServerResponse))
          return
        }

        self.session = session

        let existingItem = try? LocalBook.fetch(bookID: bookID)
        let book = existingItem ?? LocalBook(from: playSession.libraryItem)
        self.book = book
        self.totalBytes = book.orderedTracks.reduce(0) { $0 + ($1.size ?? 0) }
      } else {
        self.totalBytes = book!.orderedTracks.reduce(0) { $0 + ($1.size ?? 0) }
      }

      try await downloadTracks()

      try? book?.save()
      finish(success: true, error: nil)
    } catch {
      finish(success: false, error: error)
    }
  }

  private func downloadTracks() async throws {
    guard let book, let session else { throw URLError(.unknown) }

    let tracks = book.orderedTracks
    guard !tracks.isEmpty else { throw URLError(.badURL) }

    let bookDirectory = FileManager.default
      .urls(for: .documentDirectory, in: .userDomainMask).first!
      .appendingPathComponent("audiobooks/\(bookID)")

    try FileManager.default.createDirectory(at: bookDirectory, withIntermediateDirectories: true)

    for track in tracks {
      guard !isCancelled else { throw CancellationError() }

      let trackURL = session.url(for: track)
      let fileExtension = track.ext ?? ".mp3"
      let trackFile = bookDirectory.appendingPathComponent("\(track.index)\(fileExtension)")

      try await withCheckedThrowingContinuation { continuation in
        let downloadTask = downloadSession.downloadTask(with: trackURL)
        downloadTask.countOfBytesClientExpectsToReceive = Int64(track.size ?? 500_000_000)

        self.currentTrack = downloadTask
        self.continuation = continuation
        self.trackDestination = trackFile

        downloadTask.resume()
      }

      track.relativePath = URL(string: "audiobooks/\(bookID)/\(track.index)\(fileExtension)")

      if let size = track.size {
        bytesDownloadedSoFar += size
      }
    }
  }

  private func finish(success: Bool, error: Error?) {
    _executing = false
    _finished = true

    progressContinuation.finish()
    downloadSession.invalidateAndCancel()

    if let session = session {
      Task {
        try await audiobookshelf.sessions.close(session.id)
      }
    }

    if success {
      print("Download completed")
    } else if let error = error {
      let isCancelled = (error as? URLError)?.code == .cancelled || error is CancellationError
      if !isCancelled {
        print("Download failed: \(error.localizedDescription)")
      }
    }
  }

  private func updateProgress(totalBytesWritten: Int64) {
    guard totalBytes > 0 else { return }
    let totalBytesDownloaded = bytesDownloadedSoFar + totalBytesWritten
    let newProgress = Double(totalBytesDownloaded) / Double(totalBytes)
    progressContinuation.yield(newProgress)
  }

  private func trackDownloadCompleted(location: URL) throws {
    guard let destination = trackDestination else {
      throw URLError(.cannotCreateFile)
    }

    if FileManager.default.fileExists(atPath: destination.path) {
      try FileManager.default.removeItem(at: destination)
    }

    try FileManager.default.moveItem(at: location, to: destination)
    continuation?.resume()
  }
}

extension DownloadOperation: URLSessionDownloadDelegate {
  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    guard currentTrack == downloadTask else { return }
    updateProgress(totalBytesWritten: totalBytesWritten)
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard
      let downloadTask = task as? URLSessionDownloadTask,
      currentTrack == downloadTask,
      continuation != nil
    else { return }

    if let error {
      continuation?.resume(throwing: error)
    }
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    guard currentTrack == downloadTask, continuation != nil else { return }

    do {
      try trackDownloadCompleted(location: location)
    } catch {
      continuation?.resume(throwing: error)
    }
  }
}
