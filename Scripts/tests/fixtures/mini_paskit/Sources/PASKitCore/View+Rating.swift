import SwiftUI

public extension View {
    /// Access is inherited from the enclosing `public extension` — this is
    /// the exact shape that a plain `grep public` misses.
    func presentAppRating(
        initialCondition: @escaping () -> Bool,
        keys: String = "default"
    ) -> some View {
        self
    }
}
