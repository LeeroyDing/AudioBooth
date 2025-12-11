import AppIntents
import Models
import PlayerIntents
import SwiftUI
import WidgetKit

struct AudioBoothWidgetView: View {
  let entry: AudioBoothWidgetEntry
  @Environment(\.widgetFamily) var widgetFamily

  var body: some View {
    if let playbackState = entry.playbackState {
      Group {
        switch widgetFamily {
        case .systemSmall:
          smallWidgetView(playbackState: playbackState)
        case .systemMedium:
          mediumWidgetView(playbackState: playbackState)
        default:
          smallWidgetView(playbackState: playbackState)
        }
      }
      .widgetURL(URL(string: "audiobooth://play/\(playbackState.bookID)"))
      .containerBackground(for: .widget) {
        LinearGradient(
          colors: [Color.black.opacity(0.8), Color.black.opacity(0.95)],
          startPoint: .top,
          endPoint: .bottom
        )
      }
    } else {
      emptyStateView
    }
  }

  private func smallWidgetView(playbackState: PlaybackState) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      if let coverImage = entry.coverImage {
        Image(uiImage: coverImage)
          .resizable()
          .widgetAccentedRenderingMode(.desaturated)
          .aspectRatio(contentMode: .fill)
          .frame(width: 70, height: 70)
          .clipShape(RoundedRectangle(cornerRadius: 8))
      } else {
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.gray)
          .frame(width: 70, height: 70)
          .overlay(
            Image(systemName: "book.fill")
              .foregroundStyle(.white.opacity(0.5))
          )
      }

      Spacer()

      Text(playbackState.title)
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)

      Spacer()

      HStack(spacing: 4) {
        playPauseButton(isPlaying: playbackState.isPlaying)

        let remaining = playbackState.duration - playbackState.currentTime
        Text(formatTime(remaining))
          .font(.caption2)
          .foregroundStyle(.white.opacity(0.8))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func mediumWidgetView(playbackState: PlaybackState) -> some View {
    HStack(spacing: 12) {
      if let coverImage = entry.coverImage {
        Image(uiImage: coverImage)
          .resizable()
          .widgetAccentedRenderingMode(.desaturated)
          .aspectRatio(contentMode: .fill)
          .frame(width: 120, height: 120)
          .clipShape(RoundedRectangle(cornerRadius: 12))
      } else {
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.gray)
          .frame(width: 120, height: 120)
          .overlay(
            Image(systemName: "book.fill")
              .font(.system(size: 40))
              .foregroundStyle(.white.opacity(0.5))
          )
      }

      VStack(alignment: .leading, spacing: 8) {
        VStack(alignment: .leading, spacing: 2) {
          Text(playbackState.title)
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .lineLimit(2)

          Text(playbackState.author)
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.8))
            .lineLimit(1)
        }

        VStack(alignment: .leading, spacing: 6) {
          GeometryReader { geometry in
            ZStack(alignment: .leading) {
              RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.2))
                .frame(height: 6)

              RoundedRectangle(cornerRadius: 3)
                .fill(Color.white)
                .frame(
                  width: geometry.size.width * playbackState.progress,
                  height: 6
                )
            }
          }
          .frame(height: 6)

          let remaining = playbackState.duration - playbackState.currentTime
          Text(formatTime(remaining))
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.8))
        }

        Spacer()

        HStack(spacing: 12) {
          playPauseButton(isPlaying: playbackState.isPlaying)

          Spacer()
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func playPauseButton(isPlaying: Bool) -> some View {
    Group {
      if isPlaying {
        Button(intent: PausePlaybackIntent()) {
          Image(systemName: "pause.circle.fill")
            .font(.system(size: 32))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
      } else {
        Button(intent: ResumePlaybackIntent()) {
          Image(systemName: "play.circle.fill")
            .font(.system(size: 32))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
    Duration.seconds(seconds).formatted(
      .units(
        allowed: [.hours, .minutes],
        width: .narrow
      )
    ) + " left"
  }

  private var placeholderView: some View {
    ZStack {
      Color.gray
      Image(systemName: "book.fill")
        .font(.system(size: 40))
        .foregroundStyle(.white.opacity(0.5))
    }
  }

  private var emptyStateView: some View {
    VStack(spacing: 8) {
      Image(systemName: "book.circle")
        .font(.system(size: 30))
        .foregroundStyle(.primary.opacity(0.5))
      Text("Select a book to begin")
        .font(.caption2)
        .foregroundStyle(.primary.opacity(0.7))
    }
    .containerBackground(for: .widget) {
      Color.clear
    }
  }
}
