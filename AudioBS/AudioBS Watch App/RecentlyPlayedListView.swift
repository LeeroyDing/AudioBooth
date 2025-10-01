import NukeUI
import SwiftUI

struct RecentlyPlayedListView: View {
  @ObservedObject var connectivityManager = WatchConnectivityManager.shared

  var body: some View {
    List(connectivityManager.recentlyPlayed) { item in
      Button {
        connectivityManager.playBook(bookID: item.bookID)
      } label: {
        HStack(spacing: 12) {
          if let coverURL = item.coverURL {
            LazyImage(url: coverURL) { state in
              if let image = state.image {
                image
                  .resizable()
                  .aspectRatio(contentMode: .fill)
              } else {
                Color.gray
              }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 6))
          }

          VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
              .font(.headline)
              .lineLimit(2)

            if !item.author.isEmpty {
              Text(item.author)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            if item.timeRemaining > 0 {
              Text(formatTimeRemaining(item.timeRemaining))
                .font(.caption2)
                .foregroundStyle(.orange)
            }
          }
        }
      }
      .buttonStyle(.plain)
    }
    .navigationTitle("Recently Played")
  }

  private func formatTimeRemaining(_ duration: Double) -> String {
    Duration.seconds(duration).formatted(
      .units(
        allowed: [.hours, .minutes],
        width: .narrow
      )
    ) + " left"
  }
}

#Preview {
  RecentlyPlayedListView()
}
