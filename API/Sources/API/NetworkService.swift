import Foundation

enum HTTPMethod: String {
  case get = "GET"
  case post = "POST"
  case put = "PUT"
  case patch = "PATCH"
  case delete = "DELETE"
}

struct NetworkRequest<T: Decodable> {
  let path: String
  let method: HTTPMethod
  let body: (any Encodable)?
  let query: [String: String]?
  let headers: [String: String]?
  let timeout: TimeInterval?
  let discretionary: Bool

  init(
    path: String, method: HTTPMethod = .get, body: (any Encodable)? = nil,
    query: [String: String]? = nil, headers: [String: String]? = nil, timeout: TimeInterval? = nil,
    discretionary: Bool = false
  ) {
    self.path = path
    self.method = method
    self.body = body
    self.query = query
    self.headers = headers
    self.timeout = timeout
    self.discretionary = discretionary
  }
}

struct NetworkResponse<T: Decodable> {
  let value: T
}

final class NetworkService {
  private let baseURL: URL
  private let headersProvider: () -> [String: String]

  private let session: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 30
    config.timeoutIntervalForResource = 60

    #if os(watchOS)
      config.timeoutIntervalForResource = 300
      config.allowsExpensiveNetworkAccess = true
      config.allowsConstrainedNetworkAccess = true
      config.allowsCellularAccess = true
    #endif

    return URLSession(configuration: config)
  }()

  private let discretionarySession: URLSession = {
    let discretionaryConfig = URLSessionConfiguration.default
    discretionaryConfig.timeoutIntervalForRequest = 30
    discretionaryConfig.timeoutIntervalForResource = 60

    #if os(watchOS)
      discretionaryConfig.timeoutIntervalForResource = 300
      discretionaryConfig.allowsExpensiveNetworkAccess = true
      discretionaryConfig.allowsConstrainedNetworkAccess = true
      discretionaryConfig.allowsCellularAccess = true
      discretionaryConfig.waitsForConnectivity = true
    #endif

    #if os(iOS)
      discretionaryConfig.sessionSendsLaunchEvents = true
      discretionaryConfig.isDiscretionary = true
      discretionaryConfig.shouldUseExtendedBackgroundIdleMode = true
    #endif

    return URLSession(configuration: discretionaryConfig)
  }()

  private let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let timestamp = try container.decode(Int64.self)
      return Date(timeIntervalSince1970: TimeInterval(timestamp / 1000))
    }
    return decoder
  }()

  init(baseURL: URL, headersProvider: @escaping () -> [String: String] = { [:] }) {
    self.baseURL = baseURL
    self.headersProvider = headersProvider
  }

  func send<T: Decodable>(_ request: NetworkRequest<T>) async throws -> NetworkResponse<T> {
    let urlRequest = try buildURLRequest(from: request)

    let selectedSession = request.discretionary ? discretionarySession : session
    let (data, response) = try await selectedSession.data(for: urlRequest)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw URLError(.badServerResponse)
    }

    guard 200...299 ~= httpResponse.statusCode else {
      throw URLError(.badServerResponse)
    }

    let decodedValue: T
    if T.self == Data.self {
      decodedValue = data as! T
    } else if data.isEmpty {
      throw URLError(.cannotDecodeContentData)
    } else {
      do {
        decodedValue = try decoder.decode(T.self, from: data)
      } catch {
        print("Failed to decode \(T.self): \(error)")
        throw error
      }
    }
    return NetworkResponse(value: decodedValue)
  }

  private func buildURLRequest<T: Decodable>(from request: NetworkRequest<T>) throws -> URLRequest {
    var url = baseURL.appendingPathComponent(request.path)

    if let query = request.query {
      var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
      components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
      if let updatedURL = components?.url {
        url = updatedURL
      }
    }

    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = request.method.rawValue
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

    for (key, value) in headersProvider() {
      urlRequest.setValue(value, forHTTPHeaderField: key)
    }

    if let headers = request.headers {
      for (key, value) in headers {
        urlRequest.setValue(value, forHTTPHeaderField: key)
      }
    }

    if let timeout = request.timeout {
      urlRequest.timeoutInterval = timeout
    }

    if let body = request.body {
      urlRequest.httpBody = try JSONEncoder().encode(body)
    }

    return urlRequest
  }
}
