import Foundation

public enum ApplicationError: Error, Sendable, Equatable {
    case invalidArgument(String)
    case notFound
    case invalidState
}
