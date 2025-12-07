import API
import Combine
import SwiftUI

struct ServerView: View {
  enum FocusField: Hashable {
    case serverURL
    case username
    case password
  }

  @Environment(\.dismiss) var dismiss

  @FocusState private var focusedField: FocusField?

  @StateObject var model: Model

  var body: some View {
    Form {
      if model.authenticationModel != nil {
        discovery
      }

      Section("Server Configuration") {
        if model.authenticationModel == nil {
          TextField("Alias (optional)", text: $model.alias)
            .autocorrectionDisabled()
            .onChange(of: model.alias) { _, newValue in
              model.onAliasChanged(newValue)
            }
        }

        if !model.isTypingScheme {
          Picker("Protocol", selection: $model.serverScheme) {
            Text("https://").tag(ServerView.Model.ServerScheme.https)
            Text("http://").tag(ServerView.Model.ServerScheme.http)
          }
          .pickerStyle(.segmented)
          .disabled(model.authenticationModel == nil)
        }

        TextField("Server URL", text: $model.serverURL)
          .autocorrectionDisabled()
          .textInputAutocapitalization(.never)
          .disabled(model.authenticationModel == nil)
          .focused($focusedField, equals: .serverURL)
          .submitLabel(.next)
          .onSubmit {
            focusedField = .username
          }

        if model.authenticationModel != nil {
          Toggle("Use Subdirectory", isOn: $model.useSubdirectory)

          if model.useSubdirectory {
            TextField("Subdirectory Path", text: $model.subdirectory)
              .autocorrectionDisabled()
              .textInputAutocapitalization(.never)
          }
        }

        customHeadersSection
      }

      if let authModel = model.authenticationModel {
        AuthenticationView(model: authModel)
      } else {
        account
      }
    }
    .navigationTitle("Server")
    .alert("Scan Local Network", isPresented: $model.showDiscoveryPortAlert) {
      TextField("Discovery Port", text: $model.discoveryPort)
        .keyboardType(.numberPad)
      Button("Cancel", role: .cancel) {}
      Button("Scan") {
        if let viewModel = model as? ServerViewModel {
          viewModel.performDiscovery()
        }
      }
      .disabled(model.discoveryPort.isEmpty)
    } message: {
      Text("Enter the port number to scan for Audiobookshelf servers on your local network.")
    }
    .onAppear(perform: model.onAppear)
  }

  @ViewBuilder
  var discovery: some View {
    Section("Network Discovery") {
      Button(action: model.onDiscoverServersTapped) {
        HStack {
          if model.isDiscovering {
            ProgressView()
              .scaleEffect(0.8)
          } else {
            Image(systemName: "network")
          }
          Text(model.isDiscovering ? "Scanning network..." : "Scan Local Network")
        }
      }
      .disabled(model.isDiscovering)

      ForEach(model.discoveredServers) { server in
        Button(action: { model.onServerSelected(server) }) {
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(server.serverURL.absoluteString)
                .foregroundColor(.primary)
              Spacer()
              Text("\(Int(server.responseTime * 1000))ms")
                .font(.caption)
                .foregroundColor(.secondary)
            }
            if let info = server.serverInfo, let version = info.version {
              Text("Version: \(version)")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  var customHeadersSection: some View {
    if model.authenticationModel != nil {
      NavigationLink(
        destination: { CustomHeadersView(model: model.customHeaders) },
        label: {
          HStack {
            Image(systemName: "list.bullet.rectangle")
            Text("Custom Headers")
            Spacer()
            if model.customHeaders.headers.count > 0 {
              Text("\(model.customHeaders.headers.count)")
                .foregroundColor(.secondary)
            }
          }
        }
      )
    }
  }

  @ViewBuilder
  var account: some View {
    if model.isLoadingLibraries || !model.libraries.isEmpty {
      Section("Library") {
        if model.isLoadingLibraries {
          HStack {
            ProgressView()
              .scaleEffect(0.8)
            Text("Loading libraries...")
          }
        } else {
          ForEach(model.libraries) { library in
            Button(
              action: { model.onLibraryTapped(library) },
              label: {
                HStack {
                  Text(library.name)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(Color.primary)

                  if library.id == model.selectedLibrary?.id {
                    Image(systemName: "checkmark.circle.fill")
                      .foregroundColor(.blue)
                  }
                }
              }
            )
            .padding(.vertical, 2)
          }
        }
      }
    }

    Section("Account") {
      HStack {
        Image(
          systemName: model.reauthenticationModel != nil
            ? "exclamationmark.circle.fill" : "checkmark.circle.fill"
        )
        .foregroundColor(model.reauthenticationModel != nil ? .orange : .green)
        Text(model.reauthenticationModel != nil ? "Authentication Required" : "Authenticated")
          .bold()
      }

      if let reauthModel = model.reauthenticationModel {
        NavigationLink(destination: { AuthenticationPage(model: reauthModel) }) {
          HStack {
            Image(systemName: "arrow.clockwise")
            Text("Re-authenticate")
          }
        }
      }

      Button(
        "Logout",
        role: .destructive,
        action: {
          model.onLogoutTapped()
          dismiss()
        }
      )
    }
  }
}

extension ServerView {
  @Observable
  class Model: ObservableObject, Hashable {
    let id = UUID()

    static func == (lhs: ServerView.Model, rhs: ServerView.Model) -> Bool {
      lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }

    enum AuthenticationMethod: CaseIterable {
      case usernamePassword
      case oidc
    }

    enum ServerScheme: String, CaseIterable {
      case https = "https://"
      case http = "http://"
    }

    struct Library: Identifiable {
      let id: String
      let name: String
    }

    var isDiscovering: Bool
    var isLoadingLibraries: Bool
    var showDiscoveryPortAlert: Bool

    var serverURL: String
    var serverScheme: ServerScheme
    var useSubdirectory: Bool
    var subdirectory: String
    var customHeaders: CustomHeadersView.Model
    var discoveryPort: String
    var discoveredServers: [DiscoveredServer]
    var libraries: [Library]
    var selectedLibrary: Library?
    var alias: String
    var authenticationModel: AuthenticationView.Model?
    var reauthenticationModel: AuthenticationView.Model?
    var status: Server.Status?

    var isTypingScheme: Bool {
      let lowercased = serverURL.lowercased()
      return lowercased.hasPrefix("https://") || lowercased.hasPrefix("http://")
        || "https://".hasPrefix(lowercased) || "http://".hasPrefix(lowercased)
    }

    func onAppear() {}
    func onLogoutTapped() {}
    func onDiscoverServersTapped() {}
    func onServerSelected(_ server: DiscoveredServer) {}
    func onLibraryTapped(_ library: Library) {}
    func onAliasChanged(_ newAlias: String) {}

    init(
      isDiscovering: Bool = false,
      isLoadingLibraries: Bool = false,
      showDiscoveryPortAlert: Bool = false,
      serverURL: String = "",
      serverScheme: ServerScheme = .https,
      useSubdirectory: Bool = false,
      subdirectory: String = "",
      customHeaders: CustomHeadersView.Model = .mock,
      discoveryPort: String = "13378",
      discoveredServers: [DiscoveredServer] = [],
      libraries: [Library] = [],
      selectedLibrary: Library? = nil,
      alias: String = "",
      authenticationModel: AuthenticationView.Model? = nil,
      reauthenticationModel: AuthenticationView.Model? = nil,
      status: Server.Status? = nil
    ) {
      self.serverURL = serverURL
      self.serverScheme = serverScheme
      self.useSubdirectory = useSubdirectory
      self.subdirectory = subdirectory
      self.customHeaders = customHeaders
      self.discoveryPort = discoveryPort
      self.isDiscovering = isDiscovering
      self.isLoadingLibraries = isLoadingLibraries
      self.showDiscoveryPortAlert = showDiscoveryPortAlert
      self.discoveredServers = discoveredServers
      self.libraries = libraries
      self.selectedLibrary = selectedLibrary
      self.alias = alias
      self.authenticationModel = authenticationModel
      self.reauthenticationModel = reauthenticationModel
      self.status = status
    }
  }
}

extension ServerView.Model {
  static var mock = ServerView.Model()
}

#Preview("ServerView - Authentication") {
  ServerView(
    model: .init(
      authenticationModel: .mock
    )
  )
}

#Preview("ServerView - Authenticated with Library") {
  ServerView(
    model: .init(
      serverURL: "https://192.168.0.1:13378",
      libraries: [
        .init(id: UUID().uuidString, name: "My Library"),
        .init(id: UUID().uuidString, name: "Audiobooks"),
      ],
      selectedLibrary: .init(id: UUID().uuidString, name: "My Library")
    )
  )
}

#Preview("ServerView - Authenticated No Library") {
  ServerView(
    model: .init(
      serverURL: "https://192.168.0.1:13378"
    )
  )
}
