import SwiftUI

struct MetadataSection: View {
  let model: Model

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Metadata")
        .font(.headline)

      VStack(alignment: .leading, spacing: 8) {
        if let publisher = model.publisher {
          HStack {
            Image(systemName: "building.2")
              .accessibilityHidden(true)
            Text("**Publisher:** \(publisher)")
          }
          .font(.subheadline)
        }

        if let publishedYear = model.publishedYear {
          HStack {
            Image(systemName: "calendar")
              .accessibilityHidden(true)
            Text("**Published:** \(publishedYear)")
          }
          .font(.subheadline)
        }

        if let language = model.language {
          HStack {
            Image(systemName: "globe")
              .accessibilityHidden(true)
            Text("**Language:** \(language)")
          }
          .font(.subheadline)
        }

        if let duration = model.durationText {
          HStack {
            Image(systemName: "clock")
              .accessibilityHidden(true)
            Text("**Duration:** \(duration)")
          }
          .font(.subheadline)
        }

        if let audioProgress = model.audioProgress, audioProgress > 0, model.hasAudio {
          HStack {
            Image(systemName: "chart.bar.fill")
              .accessibilityHidden(true)
            Text("**Progress:** \(audioProgress.formatted(.percent.precision(.fractionLength(0))))")
          }
          .font(.subheadline)
        } else if let ebookProgress = model.ebookProgress, ebookProgress > 0, model.isEbook {
          HStack {
            Image(systemName: "chart.bar.fill")
              .accessibilityHidden(true)
            Text("**Progress:** \(ebookProgress.formatted(.percent.precision(.fractionLength(0))))")
          }
          .font(.subheadline)
        }

        if let timeRemaining = model.timeRemaining {
          HStack {
            Image(systemName: "clock.arrow.circlepath")
              .accessibilityHidden(true)
            Text("**Time remaining:** \(timeRemaining)")
          }
          .font(.subheadline)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

extension MetadataSection {
  struct Model {
    var publisher: String?
    var publishedYear: String?
    var language: String?
    var durationText: String?
    var timeRemaining: String?
    var hasAudio: Bool
    var isEbook: Bool
    var audioProgress: Double?
    var ebookProgress: Double?

    init(
      publisher: String? = nil,
      publishedYear: String? = nil,
      language: String? = nil,
      durationText: String? = nil,
      timeRemaining: String? = nil,
      hasAudio: Bool = false,
      isEbook: Bool = false,
      audioProgress: Double? = nil,
      ebookProgress: Double? = nil
    ) {
      self.publisher = publisher
      self.publishedYear = publishedYear
      self.language = language
      self.durationText = durationText
      self.timeRemaining = timeRemaining
      self.hasAudio = hasAudio
      self.isEbook = isEbook
      self.audioProgress = audioProgress
      self.ebookProgress = ebookProgress
    }
  }
}
