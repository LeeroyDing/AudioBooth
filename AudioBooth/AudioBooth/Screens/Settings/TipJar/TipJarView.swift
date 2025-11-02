import Combine
import RevenueCat
import StoreKit
import SwiftUI

struct TipJarView: View {
  @ObservedObject var model: Model

  var body: some View {
    if !model.tips.isEmpty {
      Section("Support Development") {
        VStack(spacing: 16) {
          HStack(spacing: 12) {
            ForEach(model.tips) { tip in
              Button(action: { model.onTipSelected(tip) }) {
                VStack(spacing: 8) {
                  Text(tip.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                  Text(tip.price)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                  Text(tip.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
                .allowsTightening(true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 8)
                .background(
                  RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                )
                .overlay(
                  RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(.systemGray5), lineWidth: 1)
                )
              }
              .buttonStyle(.plain)
              .allowsHitTesting(model.isPurchasing == nil)
              .opacity([nil, tip.id].contains(model.isPurchasing) ? 1.0 : 0.4)
            }
          }

          if model.lastPurchaseSuccess {
            HStack(spacing: 8) {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.body)
              Text("Thank you for your support!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
            .transition(.scale.combined(with: .opacity))
          }
        }
      }
      .animation(.easeInOut(duration: 0.3), value: model.lastPurchaseSuccess)
      .listRowBackground(Color.clear)
      .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
    }
  }
}

extension TipJarView {
  @Observable
  class Model: ObservableObject {
    struct Tip: Identifiable {
      let id: String
      let title: String
      let description: String
      let price: String
    }

    var tips: [Tip]
    var isPurchasing: String?
    var lastPurchaseSuccess: Bool

    func onTipSelected(_ tip: Tip) {}

    init(
      tips: [Tip] = [],
      isPurchasing: String? = nil,
      lastPurchaseSuccess: Bool = false
    ) {
      self.tips = tips
      self.isPurchasing = isPurchasing
      self.lastPurchaseSuccess = lastPurchaseSuccess
    }
  }
}

extension TipJarView.Model {
  static var mock = TipJarView.Model(
    tips: [
      Tip(
        id: "coffee",
        title: "Buy Me a Coffee ☕",
        description: "A small way to say thanks!",
        price: "$2.99"
      ),
      Tip(
        id: "lunch",
        title: "Buy Me Lunch 🍕",
        description: "Your support means a lot!",
        price: "$4.99"
      ),
      Tip(
        id: "dinner",
        title: "Buy Me Dinner 🍱",
        description: "You're amazing! Thank you!",
        price: "$9.99"
      ),
    ]
  )
}
//
//#Preview("TipJar - Loading") {
//  TipJarView(model: .init(isLoading: true))
//}
//
//#Preview("TipJar - Empty") {
//  TipJarView(model: .init())
//}

#Preview("TipJar") {
  TipJarView(model: .mock)
    .padding()
}
