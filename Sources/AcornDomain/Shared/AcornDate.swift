import Foundation

public struct AcornDate: Codable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    private enum CodingKeys: String, CodingKey { case year, month, day }

    public init?(year: Int, month: Int, day: Int) {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard Self.calendar.date(from: components) != nil,
              components.isValidDate(in: Self.calendar)
        else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let year = try c.decode(Int.self, forKey: .year)
        let month = try c.decode(Int.self, forKey: .month)
        let day = try c.decode(Int.self, forKey: .day)
        guard let valid = AcornDate(year: year, month: month, day: day) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid AcornDate \(year)-\(month)-\(day)"
                )
            )
        }
        self = valid
    }

    public static func today(now: Date = Date(), timeZone: TimeZone = .current) -> AcornDate {
        var calendar = Self.calendar
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        return AcornDate(year: components.year!, month: components.month!, day: components.day!)!
    }

    public func adding(days: Int) -> AcornDate {
        let base = Self.calendar.date(from: DateComponents(year: year, month: month, day: day))!
        let shifted = Self.calendar.date(byAdding: .day, value: days, to: base)!
        let components = Self.calendar.dateComponents([.year, .month, .day], from: shifted)
        return AcornDate(year: components.year!, month: components.month!, day: components.day!)!
    }

    public static func < (lhs: AcornDate, rhs: AcornDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    private static let calendar = Calendar(identifier: .gregorian)
}
