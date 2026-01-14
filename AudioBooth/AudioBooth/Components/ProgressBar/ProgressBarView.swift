import SwiftUI

public struct ProgressBarView: View {
  let progress: Double?

  public var body: some View {
    if let progress, progress > 0 {
      GeometryReader { geometry in
        VStack {
          Spacer()
          Rectangle()
            .fill(progress >= 1.0 ? .green : .accentColor)
            .frame(
              width: geometry.size.width * progress,
              height: geometry.size.height * 0.05
            )
        }
      }
    }
  }
}
