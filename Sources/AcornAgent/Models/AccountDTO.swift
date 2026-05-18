import Foundation
import AcornDomain

struct AccountDTO: Encodable {
    let id: UUID
    let name: String
    let isClosed: Bool

    init(from account: Account) {
        self.id = account.id
        self.name = account.name
        self.isClosed = account.isClosed
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case isClosed = "is_closed"
    }
}
