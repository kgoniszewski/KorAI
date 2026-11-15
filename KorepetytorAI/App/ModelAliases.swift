import Core

// SwiftUI udostępnia też Combine, w którym istnieje protokół `Subject`.
// Alias w module aplikacji ma pierwszeństwo, więc `Subject` zawsze oznacza encję.
typealias Subject = Core.Subject
