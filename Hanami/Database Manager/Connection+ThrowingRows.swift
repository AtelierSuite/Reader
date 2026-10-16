import Foundation
@preconcurrency import SQLite

/// SQLite.swift's `prepare` sequences step with `try!`, so a statement that
/// `DatabaseSuspensionGate` interrupts while the app is backgrounded crashes
/// the app. These read every row with throwing steps instead.
nonisolated extension Connection {

    func rows(_ query: QueryType) throws -> [Row] {
        try prepareRowIterator(query).map { $0 }
    }

    func rows(_ statement: String, _ bindings: Binding?...) throws -> [[Binding?]] {
        try rows(statement, bindings)
    }

    func rows(_ statement: String, _ bindings: [Binding?]) throws -> [[Binding?]] {
        let preparedStatement = try prepare(statement, bindings)
        var rows: [[Binding?]] = []
        while let row = try preparedStatement.failableNext() {
            rows.append(row)
        }
        return rows
    }
}
