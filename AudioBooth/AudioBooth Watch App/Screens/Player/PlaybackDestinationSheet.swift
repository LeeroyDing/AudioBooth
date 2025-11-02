import SwiftUI

struct PlaybackDestinationSheet: View {
  @Environment(\.dismiss) private var dismiss

  @State var model: Model

  var body: some View {
    List {
      Button(action: {
        model.onPlayOnWatch()
        dismiss()
      }) {
        Label("Play on Watch", systemImage: "applewatch")
      }

      Button(action: {
        model.onPlayOnIPhone()
        dismiss()
      }) {
        Label("Play on iPhone", systemImage: "iphone")
      }
    }
    .navigationTitle("Choose Device")
    .navigationBarTitleDisplayMode(.inline)
  }
}

extension PlaybackDestinationSheet {
  @Observable class Model: Identifiable {
    let id = UUID()

    init() {}

    func onPlayOnWatch() {}
    func onPlayOnIPhone() {}
  }
}

#Preview {
  NavigationStack {
    PlaybackDestinationSheet(
      model: PlaybackDestinationSheet.Model()
    )
  }
}
