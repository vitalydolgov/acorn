import Foundation

public protocol Versioned: Identifiable {
    var id: UUID { get }
    var version: Int { get set }
}
