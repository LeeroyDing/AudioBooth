import Foundation
import Nuke

public final class LibrariesService {
  private let audiobookshelf: Audiobookshelf
  private let userDefaults = UserDefaults.standard

  enum Keys {
    static let library = "audiobookshelf_selected_library"
  }

  init(audiobookshelf: Audiobookshelf) {
    self.audiobookshelf = audiobookshelf
  }

  public var current: Library? {
    get {
      guard let data = userDefaults.data(forKey: Keys.library) else { return nil }
      return try? JSONDecoder().decode(Library.self, from: data)
    }
    set {
      if let newValue {
        guard let data = try? JSONEncoder().encode(newValue) else { return }
        userDefaults.set(data, forKey: Keys.library)
      } else {
        userDefaults.removeObject(forKey: Keys.library)
      }
      ImagePipeline.shared.cache.removeAll()
    }
  }

  public func fetch() async throws -> [Library] {
    guard let networkService = audiobookshelf.networkService else {
      throw Audiobookshelf.AudiobookshelfError.networkError(
        "Network service not configured. Please login first.")
    }

    struct Response: Codable {
      let libraries: [Library]
    }

    let request = NetworkRequest<Response>(
      path: "/api/libraries",
      method: .get
    )

    do {
      let response = try await networkService.send(request)
      return response.value.libraries
    } catch {
      throw Audiobookshelf.AudiobookshelfError.networkError(
        "Failed to fetch libraries: \(error.localizedDescription)"
      )
    }
  }

  public func fetchPersonalized() async throws -> [PersonalizedSection] {
    guard let networkService = audiobookshelf.networkService else {
      throw Audiobookshelf.AudiobookshelfError.networkError(
        "Network service not configured. Please login first.")
    }

    guard let library = audiobookshelf.libraries.current else {
      throw Audiobookshelf.AudiobookshelfError.networkError(
        "No library selected. Please select a library first.")
    }

    let request = NetworkRequest<[PersonalizedSection]>(
      path: "/api/libraries/\(library.id)/personalized",
      method: .get
    )

    do {
      let response = try await networkService.send(request)
      return response.value
    } catch {
      throw Audiobookshelf.AudiobookshelfError.networkError(
        "Failed to fetch personalized sections: \(error.localizedDescription)"
      )
    }
  }
}
