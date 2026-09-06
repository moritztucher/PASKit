//
//  PASAccountDeletionResult.swift
//  PASKitAuth
//
//  Deletion is modelled as a result rather than a throw because one of its
//  outcomes is not a failure: Firebase requires a recent login before it will
//  delete an account, and the app's answer to that is to re-authenticate and
//  retry, not to show an error.
//

import Foundation

/// Outcome of `PASAuth.deleteAccount()`.
public enum PASAccountDeletionResult: Sendable, Equatable {

    /// The auth account is gone. Remote app data must already have been deleted
    /// — see the ordering note on `PASAuth.deleteAccount()`.
    case deleted

    /// Firebase refused because the session is too old. Have the user sign in
    /// again, then call `deleteAccount()` a second time. Not an error state:
    /// nothing was destroyed and nothing is inconsistent.
    case requiresRecentLogin

    /// Deletion failed. The payload is developer-facing text for logs; render
    /// app copy to the user rather than showing it directly.
    case failed(String)
}
