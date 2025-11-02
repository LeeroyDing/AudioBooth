import Combine
import Models
import SwiftUI

struct MediaProgressListView: View {
  @ObservedObject var model: Model

  var body: some View {
    List {
      ForEach(model.progressItems, id: \.progress.bookID) { item in
        VStack(alignment: .leading, spacing: 8) {
          Text(item.bookTitle ?? item.progress.bookID)
            .font(.headline)

          if item.bookTitle == nil {
            Text(item.progress.bookID)
              .font(.caption)
              .foregroundColor(.secondary)
          }

          HStack {
            Label(
              "Time Listened",
              systemImage: "clock"
            )
            Spacer()
            Text(formatDuration(item.progress.timeListened))
              .foregroundColor(.secondary)
          }

          HStack {
            Label(
              "Progress",
              systemImage: "chart.bar.fill"
            )
            Spacer()
            Text("\(Int(item.progress.progress * 100))%")
              .foregroundColor(.secondary)
          }

          HStack {
            Label(
              "Last Played",
              systemImage: "calendar"
            )
            Spacer()
            Text(formatDate(item.progress.lastPlayedAt))
              .foregroundColor(.secondary)
          }
        }
        .padding(.vertical, 4)
      }
    }
    .navigationTitle("Media Progress")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear(perform: model.onAppear)
  }

  private func formatDuration(_ duration: TimeInterval) -> String {
    let hours = Int(duration) / 3600
    let minutes = Int(duration) / 60 % 60
    let seconds = Int(duration) % 60

    if hours > 0 {
      return String(format: "%dh %dm %ds", hours, minutes, seconds)
    } else if minutes > 0 {
      return String(format: "%dm %ds", minutes, seconds)
    } else {
      return String(format: "%ds", seconds)
    }
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
  }
}

extension MediaProgressListView {
  struct ProgressItem {
    let progress: MediaProgress
    let bookTitle: String?
  }

  @MainActor
  @Observable
  class Model: ObservableObject {
    var progressItems: [ProgressItem]

    func onAppear() {}

    init(progressItems: [ProgressItem] = []) {
      self.progressItems = progressItems
    }
  }
}

extension MediaProgressListView.Model {
  static var mock = MediaProgressListView.Model(
    progressItems: [
      MediaProgressListView.ProgressItem(
        progress: MediaProgress(
          bookID: "book-1",
          lastPlayedAt: Date(),
          currentTime: 1800,
          timeListened: 3600,
          duration: 7200,
          progress: 0.5
        ),
        bookTitle: "The Great Gatsby"
      ),
      MediaProgressListView.ProgressItem(
        progress: MediaProgress(
          bookID: "book-2",
          lastPlayedAt: Date().addingTimeInterval(-86400),
          currentTime: 600,
          timeListened: 1200,
          duration: 3600,
          progress: 0.33
        ),
        bookTitle: "1984"
      ),
    ]
  )
}

#Preview {
  NavigationStack {
    MediaProgressListView(model: .mock)
  }
}
