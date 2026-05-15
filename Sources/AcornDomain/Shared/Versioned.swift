import Foundation

public protocol Versioned: Sendable {
    var id: UUID { get }
    var version: Int { get set }
}
