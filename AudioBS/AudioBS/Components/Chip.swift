import SwiftUI

struct Chip: View {
  let title: String
  let icon: String?
  let color: Color
  let fontWeight: Font.Weight

  init(title: String, icon: String? = nil, color: Color, fontWeight: Font.Weight = .medium) {
    self.title = title
    self.icon = icon
    self.color = color
    self.fontWeight = fontWeight
  }

  var body: some View {
    HStack(spacing: 4) {
      if let icon {
        Image(systemName: icon)
          .font(.caption2)
      }

      Text(title)
        .font(.caption)
        .fontWeight(fontWeight)
    }
    .foregroundColor(color)
    .padding(.horizontal, 10)
    .padding(.vertical, icon != nil ? 6 : 4)
    .background(color.opacity(0.1))
    .clipShape(.capsule)
    .overlay(
      Capsule()
        .stroke(color.opacity(0.3), lineWidth: 1)
    )
  }
}
