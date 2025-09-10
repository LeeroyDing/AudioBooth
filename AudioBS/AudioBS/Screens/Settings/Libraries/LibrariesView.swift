import SwiftUI

struct LibrariesView: View {
  @Environment(\.dismiss) private var dismiss

  @StateModel var model: Model

  init(model: Model? = nil) {
    if let model {
      self._model = StateModel(wrappedValue: model)
    } else {
      self._model = StateModel(mock: .mock, default: LibrariesViewModel())
    }
  }

  var body: some View {
    NavigationView {
      VStack {
        List {
          ForEach(model.rows) { row in
            Button(
              action: { model.onRowTapped(row) },
              label: {
                HStack {
                  Text(row.name)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                  if row.id == model.selected?.id {
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
    .navigationTitle("Select Library")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear(perform: model.onAppear)
  }
}

extension LibrariesView {
  @Observable class Model {
    struct Row: Identifiable {
      let id: String
      let name: String
    }
    var rows: [Row]
    var isLoading: Bool
    var selected: Row?

    @MainActor func onAppear() {}
    @MainActor func onRowTapped(_ row: Row) {}

    init(
      rows: [Row] = [],
      isLoading: Bool = false,
      selected: Row? = nil
    ) {
      self.rows = rows
      self.isLoading = isLoading
      self.selected = selected
    }
  }
}

extension LibrariesView.Model {
  static let mock = LibrariesView.Model()
}

#Preview {
  LibrariesView(model: .init())
}
