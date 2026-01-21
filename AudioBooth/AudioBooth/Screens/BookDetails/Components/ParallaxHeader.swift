import SwiftUI

struct ParallaxHeader<Content: View, Space: Hashable>: View {
  let content: () -> Content
  let coordinateSpace: Space
  @State var height: CGFloat = 0

  init(
    coordinateSpace: Space,
    @ViewBuilder _ content: @escaping () -> Content
  ) {
    self.content = content
    self.coordinateSpace = coordinateSpace
  }

  var body: some View {
    GeometryReader { proxy in
      let offset = offset(for: proxy)
      let heightModifier = heightModifier(for: proxy)
      content()
        .edgesIgnoringSafeArea(.horizontal)
        .frame(
          width: proxy.size.width,
          height: proxy.size.height + heightModifier
        )
        .offset(y: offset)
        .onAppear {
          height = min(370, proxy.size.width)
        }
        .onChange(of: proxy.size.width) { _, new in height = min(370, new) }
    }
    .frame(height: height)
    .accessibilityHidden(true)
  }

  private func offset(for proxy: GeometryProxy) -> CGFloat {
    let frame = proxy.frame(in: .named(coordinateSpace))
    if frame.minY < 0 {
      return -frame.minY * 0.8
    }
    return -frame.minY
  }

  private func heightModifier(for proxy: GeometryProxy) -> CGFloat {
    let frame = proxy.frame(in: .named(coordinateSpace))
    return max(0, frame.minY)
  }
}
