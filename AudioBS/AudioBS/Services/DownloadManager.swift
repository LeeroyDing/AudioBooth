import API
import AVFoundation
import Combine
import Foundation
import Models
import SwiftData

final class DownloadManager: NSObject, ObservableObject {
  static let shared = DownloadManager()

  private var audiobookshelf: Audiobookshelf { .shared }

  enum DownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
  }

  @Published private(set) var downloads: [String: Bool] = [:]
  @Published private(set) var downloadProgress: [String: Double] = [:]

  private var downloadTasks: [String: Task<Void, Never>] = [:]
  private var activeDownloads: [URLSessionDownloadTask: DownloadInfo] = [:]
  private var downloadContinuations: [URLSessionDownloadTask: CheckedContinuation<Void, Error>] =
    [:]
  private var urlSessionTasks: [String: [URLSessionDownloadTask]] = [:]
  private var trackDestinations: [URLSessionDownloadTask: URL] = [:]
  private lazy var downloadSession: URLSession = {
    let config = URLSessionConfiguration.default
    return URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }()

  struct DownloadInfo {
    let bookID: String
    let totalBytes: Int64
    let bytesDownloadedSoFar: Int64
  }

  func isDownloading(for bookID: String) -> Bool {
    return downloads[bookID] ?? false
  }

  func startDownload(for item: LocalBook, session: Session) {
    let tracks = item.orderedTracks
    guard !tracks.isEmpty else {
      Toast(error: "Cannot start download: missing tracks").show()
      return
    }

    let bookID = item.bookID
    downloads[bookID] = true
    downloadProgress[bookID] = 0.0

    let task = Task {
      do {
        let bookDirectory = FileManager.default
          .urls(for: .documentDirectory, in: .userDomainMask).first!
          .appendingPathComponent("audiobooks/\(bookID)")

        try FileManager.default.createDirectory(
          at: bookDirectory, withIntermediateDirectories: true)

        let totalBytes = tracks.reduce(0) { $0 + ($1.size ?? 0) }
        var bytesDownloadedSoFar: Int64 = 0

        for track in tracks {
          let trackURL = session.url(for: track)

          let fileExtension = track.ext ?? ".mp3"
          let trackFile = bookDirectory.appendingPathComponent("\(track.index)\(fileExtension)")

          try await withCheckedThrowingContinuation { continuation in
            let downloadTask = downloadSession.downloadTask(with: trackURL)

            activeDownloads[downloadTask] = DownloadInfo(
              bookID: bookID,
              totalBytes: totalBytes,
              bytesDownloadedSoFar: bytesDownloadedSoFar
            )

            downloadContinuations[downloadTask] = continuation
            trackDestinations[downloadTask] = trackFile

            if urlSessionTasks[bookID] == nil {
              urlSessionTasks[bookID] = []
            }
            urlSessionTasks[bookID]?.append(downloadTask)

            downloadTask.resume()
          }

          track.relativePath = URL(string: "audiobooks/\(bookID)/\(track.index)\(fileExtension)")

          if let size = track.size {
            bytesDownloadedSoFar += size
          }
        }

        try? item.save()
        downloads.removeValue(forKey: bookID)
        downloadProgress.removeValue(forKey: bookID)
        urlSessionTasks.removeValue(forKey: bookID)
        Toast(success: "Download completed").show()
      } catch {
        downloads.removeValue(forKey: bookID)
        downloadProgress.removeValue(forKey: bookID)
        urlSessionTasks.removeValue(forKey: bookID)

        let isCancelled = (error as? URLError)?.code == .cancelled || error is CancellationError
        if !isCancelled {
          Toast(error: "Download failed: \(error.localizedDescription)").show()
        }
      }

      downloadTasks.removeValue(forKey: bookID)
    }

    downloadTasks[bookID] = task
  }

  func startDownload(for bookID: String) {
    downloads[bookID] = true

    let task = Task {
      do {
        let playSession = try await audiobookshelf.sessions.start(itemID: bookID)

        guard let session = Session(from: playSession) else {
          downloads.removeValue(forKey: bookID)
          Toast(error: "Failed to create session").show()
          return
        }

        let book = LocalBook(from: playSession.libraryItem)

        try book.save()

        startDownload(for: book, session: session)

      } catch {
        downloads.removeValue(forKey: bookID)
        Toast(error: "Failed to start download: \(error.localizedDescription)").show()
      }
    }

    downloadTasks[bookID] = task
  }

  func cancelDownload(for bookID: String) {
    downloadTasks[bookID]?.cancel()
    downloadTasks.removeValue(forKey: bookID)

    urlSessionTasks[bookID]?.forEach { $0.cancel() }
    urlSessionTasks.removeValue(forKey: bookID)

    downloads.removeValue(forKey: bookID)
    downloadProgress.removeValue(forKey: bookID)
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
        Toast(error: "Failed to delete download: \(error.localizedDescription)").show()
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

extension DownloadManager: URLSessionDownloadDelegate {
  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    guard let downloadInfo = activeDownloads[downloadTask],
      downloadInfo.totalBytes > 0
    else {
      return
    }

    let totalBytesDownloaded = downloadInfo.bytesDownloadedSoFar + totalBytesWritten
    let totalProgress = Double(totalBytesDownloaded) / Double(downloadInfo.totalBytes)

    Task { @MainActor in
      downloadProgress[downloadInfo.bookID] = totalProgress
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let downloadTask = task as? URLSessionDownloadTask else { return }

    if let error = error, let continuation = downloadContinuations[downloadTask] {
      continuation.resume(throwing: error)
      downloadContinuations.removeValue(forKey: downloadTask)
    }

    activeDownloads.removeValue(forKey: downloadTask)
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    guard let destination = trackDestinations[downloadTask] else {
      if let continuation = downloadContinuations[downloadTask] {
        continuation.resume(throwing: URLError(.cannotCreateFile))
        downloadContinuations.removeValue(forKey: downloadTask)
      }
      activeDownloads.removeValue(forKey: downloadTask)
      return
    }

    do {
      if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
      }

      try FileManager.default.moveItem(at: location, to: destination)

      if let continuation = downloadContinuations[downloadTask] {
        continuation.resume()
        downloadContinuations.removeValue(forKey: downloadTask)
      }
    } catch {
      if let continuation = downloadContinuations[downloadTask] {
        continuation.resume(throwing: error)
        downloadContinuations.removeValue(forKey: downloadTask)
      }
    }

    activeDownloads.removeValue(forKey: downloadTask)
    trackDestinations.removeValue(forKey: downloadTask)
  }
}
