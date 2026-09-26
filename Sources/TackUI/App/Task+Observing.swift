import Observation

extension Task where Success == Void, Failure == Never {
    /// Applies the value now and again after every change, until cancelled.
    @MainActor
    static func observing<Value: Equatable & Sendable>(
        _ value: @escaping @MainActor @Sendable () -> Value,
        apply: @escaping @MainActor (Value) -> Void
    ) -> Task {
        Task { @MainActor in
            for await current in Observations(value) { apply(current) }
        }
    }
}
