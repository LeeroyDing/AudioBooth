import Foundation
import Logging
import RevenueCat
import SwiftUI

final class TipJarViewModel: TipJarView.Model {
  private var packages: [Package] = []

  init() {
    super.init(isSandbox: [.debug, .testFlight].contains(UIApplication.buildType))

    loadOfferings()
  }

  override func onTipSelected(_ tip: Tip) {
    guard let package = packages.first(where: { $0.identifier == tip.id }) else {
      return
    }
    purchaseTip(package)
  }

  private func loadOfferings() {
    Task {
      do {
        let offerings = try await Purchases.shared.offerings()

        guard let currentOffering = offerings.current else {
          AppLogger.viewModel.warning("No current offering available")
          return
        }

        packages = currentOffering.availablePackages.sorted { lhs, rhs in
          return lhs.storeProduct.price < rhs.storeProduct.price
        }

        tips = packages.map { package in
          var title = package.storeProduct.localizedTitle
          var price = package.localizedPriceString

          switch package.identifier {
          case "tip_small":
            title += " ☕"
          case "tip_medium":
            title += " 🍕"
          case "tip_large":
            title += " 🍱"
          case "$rc_monthly":
            price += "/mo"
          default:
            break
          }

          return Tip(
            id: package.identifier,
            title: title,
            description: package.storeProduct.localizedDescription,
            price: price
          )
        }
      } catch {
        AppLogger.viewModel.error(
          "Failed to fetch offerings: \(error.localizedDescription)"
        )
      }
    }
  }

  private func purchaseTip(_ package: Package) {
    isPurchasing = package.identifier
    lastPurchaseSuccess = false

    Task {
      do {
        let result = try await Purchases.shared.purchase(package: package)

        if !result.userCancelled {
          lastPurchaseSuccess = true

          Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            lastPurchaseSuccess = false
          }
        }
      } catch {
        AppLogger.viewModel.error(
          "Failed to purchase tip: \(error.localizedDescription)"
        )
      }

      isPurchasing = nil
    }
  }
}
