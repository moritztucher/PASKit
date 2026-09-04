import SwiftUI

public extension Animation {
    func respectingReducedMotion(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : self
    }
}
