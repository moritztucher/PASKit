//
//  FeedbackPayload.swift
//  PASKitLifecycle
//
//  The data shape `FeedbackSheet` hands back to its `onSubmit` closure.
//

import Foundation

public struct FeedbackPayload: Sendable, Equatable {
    public let category: String
    public let name: String
    public let email: String
    public let message: String

    public init(category: String, name: String, email: String, message: String) {
        self.category = category
        self.name = name
        self.email = email
        self.message = message
    }
}
