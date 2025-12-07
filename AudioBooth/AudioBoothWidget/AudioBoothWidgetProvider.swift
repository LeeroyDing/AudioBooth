import Foundation
import Models
import Nuke
import UIKit
import WidgetKit

struct AudioBoothWidgetEntry: TimelineEntry {
  let date: Date
  let playbackState: PlaybackState?
  let coverImage: UIImage?
}

struct AudioBoothWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> AudioBoothWidgetEntry {
    AudioBoothWidgetEntry(
      date: Date(),
      playbackState: nil,
      coverImage: nil
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (AudioBoothWidgetEntry) -> Void) {
    Task {
      let entry = await getCurrentBookEntry()
      completion(entry)
    }
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<AudioBoothWidgetEntry>) -> Void
  ) {
    Task {
      let entry = await getCurrentBookEntry()
      let timeline = Timeline(entries: [entry], policy: .never)
      completion(timeline)
    }
  }

  @MainActor
  private func getCurrentBookEntry() async -> AudioBoothWidgetEntry {
    let sharedDefaults = UserDefaults(suiteName: "group.me.jgrenier.audioBS")

    guard let data = sharedDefaults?.data(forKey: "playbackState"),
      let playbackState = try? JSONDecoder().decode(PlaybackState.self, from: data)
    else {
      return AudioBoothWidgetEntry(
        date: Date(),
        playbackState: nil,
        coverImage: nil
      )
    }

    var coverImage: UIImage?
    if let coverURL = playbackState.coverURL {
      var thumbnailURL = coverURL
      if var components = URLComponents(url: coverURL, resolvingAgainstBaseURL: false) {
        components.query = "width=500"
        thumbnailURL = components.url ?? coverURL
      }

      do {
        let request = ImageRequest(url: thumbnailURL)
        coverImage = try await ImagePipeline.shared.image(for: request)
      } catch {
      }
    }

    return AudioBoothWidgetEntry(
      date: Date(),
      playbackState: playbackState,
      coverImage: coverImage
    )
  }
}
