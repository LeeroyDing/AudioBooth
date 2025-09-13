import NukeUI
import SwiftUI

struct MiniBookPlayer: View {
  var player: BookPlayer.Model
  let onTap: () -> Void

  var body: some View {
    if #available(iOS 26.0, *) {
      content
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .glassEffect()
        .padding(.horizontal, 21)
        .padding(.bottom, 12)
    } else {
      content
        .background(.regularMaterial)
        .contentShape(Rectangle())
        .onTapGesture {
          onTap()
        }
    }
  }

  @ViewBuilder
  var content: some View {
    HStack {
      cover

      VStack(alignment: .leading, spacing: 2) {
        Text(player.title)
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.primary)
          .lineLimit(1)

        if let author = player.author {
          Text(author)
            .font(.caption2)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }

        Text(formatTimeRemaining(player.playbackProgress.totalTimeRemaining))
          .font(.caption)
          .foregroundColor(.secondary)
          .fontWeight(.medium)
      }

      Spacer()

      Button(action: player.onTogglePlaybackTapped) {
        ZStack {
          Circle()
            .fill(Color.blue)
            .frame(width: 40, height: 40)

          if player.isLoading {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: .white))
              .scaleEffect(0.7)
          } else {
            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
              .font(.system(size: 16))
              .foregroundColor(.white)
              .offset(x: player.isPlaying ? 0 : 2)
          }
        }
      }
      .disabled(player.isLoading)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
  }

  private var cover: some View {
    LazyImage(url: player.coverURL) { state in
      if let image = state.image {
        image
          .resizable()
          .aspectRatio(1, contentMode: .fill)
      } else {
        Rectangle()
          .fill(Color.gray.opacity(0.3))
          .overlay {
            Image(systemName: "book.closed")
              .foregroundColor(.gray)
              .font(.system(size: 16))
          }
      }
    }
    .frame(width: 50, height: 50)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  private func formatTimeRemaining(_ duration: TimeInterval) -> String {
    Duration.seconds(duration).formatted(
      .units(
        allowed: [.hours, .minutes],
        width: .narrow
      )
    ) + " remaining"
  }
}

#Preview {
  VStack {
    Spacer()
    MiniBookPlayer(player: .mock) {
      print("Tapped mini player")
    }
  }
}
