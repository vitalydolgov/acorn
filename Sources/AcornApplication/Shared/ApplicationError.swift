import Foundation

public enum ApplicationError: Error, Sendable, Equatable {
    case notFound(UUID)
    case notFound(name: String)
    case invalidArgument(String)
    case invalidState(String)
}
