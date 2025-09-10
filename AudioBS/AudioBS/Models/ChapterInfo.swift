import Audiobookshelf
import Foundation
import SwiftData

@Model
final class ChapterInfo {
  var id: Int
  var start: TimeInterval
  var end: TimeInterval
  var title: String

  init(from chapter: PlaySession.Chapter) {
    self.id = chapter.id
    self.start = chapter.start
    self.end = chapter.end
    self.title = chapter.title
  }
}
