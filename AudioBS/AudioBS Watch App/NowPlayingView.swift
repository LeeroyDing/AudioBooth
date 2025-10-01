import NukeUI
import SwiftUI

struct NowPlayingView: View {
  @ObservedObject var connectivityManager = WatchConnectivityManager.shared

  var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        CoverArtView(coverURL: connectivityManager.coverURL)

        TitleAuthorView(title: connectivityManager.title, author: connectivityManager.author)

        PlaybackProgressView()

        PlaybackControlsView(
          isPlaying: connectivityManager.isPlaying,
          onTogglePlayback: { connectivityManager.togglePlayback() },
          onSkipBackward: { connectivityManager.skipBackward() },
          onSkipForward: { connectivityManager.skipForward() }
        )

        PlaybackSpeedView(playbackSpeed: connectivityManager.playbackSpeed)
      }
      .padding()
    }
    .navigationTitle("Playing")
  }
}

extension NowPlayingView {
  private struct CoverArtView: View {
    let coverURL: URL?

    var body: some View {
      if let coverURL {
        LazyImage(url: coverURL) { state in
          if let image = state.image {
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
          } else {
            Color.gray
          }
        }
        .frame(width: 120, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }
    }
  }
}

extension NowPlayingView {
  private struct TitleAuthorView: View {
    let title: String
    let author: String

    var body: some View {
      VStack(spacing: 4) {
        Text(title)
          .font(.headline)
          .lineLimit(2)
          .multilineTextAlignment(.center)

        if !author.isEmpty {
          Text(author)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
    }
  }
}

extension NowPlayingView {
  struct PlaybackProgressView: View {
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared

    var body: some View {
      VStack(spacing: 4) {
        ProgressView(value: connectivityManager.progress, total: 1.0)

        HStack {
          Text(formatTime(connectivityManager.current))
            .font(.caption2)
            .foregroundStyle(.secondary)

          Spacer()

          Text("-\(formatTime(connectivityManager.remaining))")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .monospacedDigit()

        Text(formatTimeRemaining(connectivityManager.totalTimeRemaining))
          .font(.caption2)
          .fontWeight(.medium)
      }
    }

    private func formatTime(_ seconds: Double) -> String {
      Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond))
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
}

extension NowPlayingView {
  private struct PlaybackControlsView: View {
    let isPlaying: Bool
    let onTogglePlayback: () -> Void
    let onSkipBackward: () -> Void
    let onSkipForward: () -> Void

    var body: some View {
      HStack(spacing: 20) {
        Button(action: onSkipBackward) {
          Image(systemName: "gobackward.30")
            .font(.title2)
        }
        .buttonStyle(.plain)

        Button(action: onTogglePlayback) {
          Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            .font(.title)
        }
        .buttonStyle(.plain)

        Button(action: onSkipForward) {
          Image(systemName: "goforward.30")
            .font(.title2)
        }
        .buttonStyle(.plain)
      }
      .padding(.top, 8)
    }
  }
}

extension NowPlayingView {
  private struct PlaybackSpeedView: View {
    let playbackSpeed: Float

    var body: some View {
      if playbackSpeed != 1.0 {
        Text("\(playbackSpeed, specifier: "%.1f")x")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}

#Preview {
  NowPlayingView()
}
