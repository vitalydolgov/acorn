import Foundation
import AcornDomain

struct AccountDTO: Encodable {
    let id: UUID
    let name: String
    let notes: String
    let isClosed: Bool

    init(from account: Account) {
        self.id = account.id
        self.name = account.name
        self.notes = account.notes
        self.isClosed = account.isClosed
    }

    enum CodingKeys: String, CodingKey {
        case id, name, notes
        case isClosed = "is_closed"
    }
}
