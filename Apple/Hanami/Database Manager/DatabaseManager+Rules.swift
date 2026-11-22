import Foundation
@preconcurrency import SQLite

public nonisolated extension DatabaseManager {

    // MARK: - Feed Rules CRUD

    func rules(forFeedID feedID: Int64, type: String) throws -> [String] {
        try readDatabase.rows(
            feedRules
                .filter(ruleFeedID == feedID && ruleType == type)
                .order(ruleValue.asc)
        ).map { $0[ruleValue] }
    }

    func allRules(forFeedID feedID: Int64) throws -> [String: [String]] {
        var result: [String: [String]] = [:]
        let query = feedRules
            .filter(ruleFeedID == feedID)
            .order(ruleValue.asc)
        for row in try readDatabase.rows(query) {
            result[row[ruleType], default: []].append(row[ruleValue])
        }
        return result
    }

    func allRulesByFeedID() throws -> [Int64: [String: [String]]] {
        var result: [Int64: [String: [String]]] = [:]
        for row in try readDatabase.rows(feedRules.order(ruleValue.asc)) {
            result[row[ruleFeedID], default: [:]][row[ruleType], default: []].append(row[ruleValue])
        }
        return result
    }

    func replaceRules(feedID: Int64, type: String, values: [String]) throws {
        let existing = feedRules.filter(ruleFeedID == feedID && ruleType == type)
        try database.run(existing.delete())
        for value in values {
            try database.run(feedRules.insert(
                ruleFeedID <- feedID,
                ruleType <- type,
                ruleValue <- value
            ))
        }
    }
}
