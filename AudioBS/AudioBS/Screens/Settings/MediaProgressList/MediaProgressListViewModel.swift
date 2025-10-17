import Foundation
import Models

@MainActor
final class MediaProgressListViewModel: MediaProgressListView.Model {
  init() {
    super.init(progressItems: [])
  }

  override func onAppear() {
    loadMediaProgress()
  }

  private func loadMediaProgress() {
    do {
      let allProgress = try MediaProgress.fetchAll()
      let filteredProgress = allProgress.filter { $0.timeListened > 0 }

      progressItems = filteredProgress.map { progress in
        let bookTitle = try? LocalBook.fetch(bookID: progress.bookID)?.title
        return MediaProgressListView.ProgressItem(
          progress: progress,
          bookTitle: bookTitle
        )
      }
    } catch {
      print("Failed to fetch media progress: \(error.localizedDescription)")
      progressItems = []
    }
  }
}
