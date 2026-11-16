extension Optional {
    /// `true`, gdy wartość istnieje; ustawienie `false` czyści wartość.
    ///
    /// Służy jako `isPresented` dla okien sterowanych opcjonalnym stanem:
    /// `.alert(…, isPresented: $errorText.isPresent)`. Wiązanie powstaje przez
    /// wbudowany `dynamicMember` w `Binding`, bez własnego `Binding(get:set:)`,
    /// którego domknięcia w Swift 6 muszą być `@Sendable` (a modele SwiftData nie są).
    var isPresent: Bool {
        get { self != nil }
        set {
            if !newValue {
                self = nil
            }
        }
    }
}
