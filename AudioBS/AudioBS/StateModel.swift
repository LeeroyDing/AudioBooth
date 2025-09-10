import SwiftUI

@propertyWrapper
struct StateModel<T>: DynamicProperty {
  @State private var model: T

  init(wrappedValue: T) {
    self._model = State(wrappedValue: wrappedValue)
  }

  init(mock: T, default: T) {
    let resolvedModel: T

    #if DEBUG
      if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
        resolvedModel = mock
      } else {
        resolvedModel = `default`
      }
    #else
      resolvedModel = `default`
    #endif

    self._model = State(wrappedValue: resolvedModel)
  }

  var wrappedValue: T {
    get { model }
    nonmutating set { model = newValue }
  }

  var projectedValue: Binding<T> { $model }
}
