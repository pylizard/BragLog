//
//  Migrations.swift
//  BragLog
//

import Foundation
import SQLite3

enum Migrations {
    static let currentVersion: Int32 = 1

    static func runMigration(_ version: Int32, on db: OpaquePointer?) -> Bool {
        switch version {
        case 1:
            return runV1(db)
        default:
            return false
        }
    }

    private static func runV1(_ db: OpaquePointer?) -> Bool {
        let sql = """
        CREATE TABLE IF NOT EXISTS logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            message TEXT NOT NULL,
            tags TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS tag (
            name TEXT PRIMARY KEY
        );
        PRAGMA user_version = 1;
        """
        return sql.components(separatedBy: ";").compactMap { s -> String? in
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }.allSatisfy { statement in
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, statement + ";", -1, &stmt, nil) == SQLITE_OK else { return false }
            return sqlite3_step(stmt) == SQLITE_DONE
        }
    }
}
