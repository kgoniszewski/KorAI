import SwiftUI

extension Binding {
    /// Wiązanie `isPresented` dla opcjonalnego stanu: okno jest widoczne, gdy wartość istnieje,
    /// a jego zamknięcie czyści wartość.
    func isPresent<Wrapped>() -> Binding<Bool> where Value == Wrapped? {
        Binding<Bool>(
            get: { wrappedValue != nil },
            set: { newValue in
                if !newValue {
                    wrappedValue = nil
                }
            }
        )
    }
}
