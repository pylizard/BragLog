//
//  DatabaseService.swift
//  BragLog
//

import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum DatabaseError: Error, CustomStringConvertible {
    case openFailed(String)
    case migrationFailed
    case prepareFailed(String)
    case stepFailed(String)
    case importBackupFailed(String)
    case importCopyFailed(String)

    var description: String {
        switch self {
        case .openFailed(let msg): return "Open failed: \(msg)"
        case .migrationFailed: return "Migration failed"
        case .prepareFailed(let msg): return "Prepare failed: \(msg)"
        case .stepFailed(let msg): return "Step failed: \(msg)"
        case .importBackupFailed(let msg): return "Backup failed: \(msg)"
        case .importCopyFailed(let msg): return "Import failed: \(msg)"
        }
    }
}

final class DatabaseService {
    private var db: OpaquePointer?
    private let dbPath: String
    private let fileManager: FileManager

    static func defaultDatabasePath() -> String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bragLogDir = appSupport.appendingPathComponent("BragLog", isDirectory: true)
        return bragLogDir.appendingPathComponent("log.db").path
    }

    init(dbPath: String? = nil, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        self.dbPath = dbPath ?? Self.defaultDatabasePath()
        if self.dbPath != ":memory:" {
            let dir = (self.dbPath as NSString).deletingLastPathComponent
            try fileManager.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }
        var dbPointer: OpaquePointer?
        let openResult = sqlite3_open_v2(self.dbPath, &dbPointer, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
        guard openResult == SQLITE_OK, let ptr = dbPointer else {
            let msg = String(cString: sqlite3_errmsg(dbPointer))
            sqlite3_close(dbPointer)
            throw DatabaseError.openFailed(msg)
        }
        self.db = ptr
        try runMigrations()
    }

    deinit {
        sqlite3_close(db)
    }

    private func runMigrations() throws {
        let current = sqlite3_user_version(db)
        var version = current
        while version < Migrations.currentVersion {
            version += 1
            guard Migrations.runMigration(version, on: db) else {
                throw DatabaseError.migrationFailed
            }
        }
    }

    private func sqlite3_user_version(_ db: OpaquePointer?) -> Int32 {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &stmt, nil) == SQLITE_OK else { return 0 }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return sqlite3_column_int(stmt, 0)
    }

    func fetchAllTags() throws -> [Tag] {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = "SELECT name FROM tag ORDER BY name COLLATE NOCASE"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        var result: [Tag] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let name = String(cString: sqlite3_column_text(stmt, 0))
            result.append(Tag(name: name))
        }
        return result
    }

    func fetchAllProjects() throws -> [Project] {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = "SELECT name FROM project ORDER BY name COLLATE NOCASE"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        var result: [Project] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let name = String(cString: sqlite3_column_text(stmt, 0))
            result.append(Project(name: name))
        }
        return result
    }

    func saveEntry(message: String, tags: [String]?, project: String? = nil) throws {
        let normalized = (tags ?? []).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let tagsString: String? = normalized.isEmpty ? nil : normalized.joined(separator: ",")
        for tag in normalized {
            var insertTag: OpaquePointer?
            defer { sqlite3_finalize(insertTag) }
            let tagSql = "INSERT OR IGNORE INTO tag (name) VALUES (?1)"
            guard sqlite3_prepare_v2(db, tagSql, -1, &insertTag, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            sqlite3_bind_text(insertTag, 1, tag, -1, SQLITE_TRANSIENT)
            guard sqlite3_step(insertTag) == SQLITE_DONE else {
                throw DatabaseError.stepFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
        let projectTrimmed = project?.trimmingCharacters(in: .whitespaces)
        let projectValue: String? = (projectTrimmed?.isEmpty ?? true) ? nil : projectTrimmed
        if let p = projectValue {
            var insertProject: OpaquePointer?
            defer { sqlite3_finalize(insertProject) }
            let projectSql = "INSERT OR IGNORE INTO project (name) VALUES (?1)"
            guard sqlite3_prepare_v2(db, projectSql, -1, &insertProject, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            sqlite3_bind_text(insertProject, 1, p, -1, SQLITE_TRANSIENT)
            guard sqlite3_step(insertProject) == SQLITE_DONE else {
                throw DatabaseError.stepFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
        var insertLog: OpaquePointer?
        defer { sqlite3_finalize(insertLog) }
        let logSql = "INSERT INTO logs (message, tags, project) VALUES (?1, ?2, ?3)"
        guard sqlite3_prepare_v2(db, logSql, -1, &insertLog, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        sqlite3_bind_text(insertLog, 1, message, -1, SQLITE_TRANSIENT)
        if let t = tagsString {
            sqlite3_bind_text(insertLog, 2, t, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(insertLog, 2)
        }
        if let p = projectValue {
            sqlite3_bind_text(insertLog, 3, p, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(insertLog, 3)
        }
        guard sqlite3_step(insertLog) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    func importDatabase(from sourceURL: URL) throws {
        let path = sourceURL.path
        guard fileManager.fileExists(atPath: path), fileManager.isReadableFile(atPath: path) else {
            throw DatabaseError.importCopyFailed("File not found or not readable")
        }
        var backupPath: String?
        if dbPath != ":memory:" && fileManager.fileExists(atPath: dbPath) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let backupName = "log.db.backup.\(formatter.string(from: Date()))"
            let bp = (dbPath as NSString).deletingLastPathComponent + "/" + backupName
            do {
                try fileManager.copyItem(atPath: dbPath, toPath: bp)
                backupPath = bp
            } catch {
                throw DatabaseError.importBackupFailed(error.localizedDescription)
            }
        }
        sqlite3_close(db)
        db = nil
        do {
            try fileManager.removeItem(atPath: dbPath)
        } catch {}
        do {
            try fileManager.copyItem(atPath: path, toPath: dbPath)
        } catch {
            if let bp = backupPath {
                try? fileManager.copyItem(atPath: bp, toPath: dbPath)
                var restored: OpaquePointer?
                if sqlite3_open_v2(dbPath, &restored, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK {
                    db = restored
                }
            }
            throw DatabaseError.importCopyFailed(error.localizedDescription)
        }
        var dbPointer: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &dbPointer, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK, let ptr = dbPointer else {
            throw DatabaseError.openFailed(String(cString: sqlite3_errmsg(dbPointer)))
        }
        db = ptr
        try runMigrations()
    }

    func fetchLastLogRawTags() throws -> String? {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = "SELECT tags FROM logs ORDER BY id DESC LIMIT 1"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        if sqlite3_column_type(stmt, 0) == SQLITE_NULL { return nil }
        return String(cString: sqlite3_column_text(stmt, 0))
    }

    func fetchLastLogRawProject() throws -> String? {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = "SELECT project FROM logs ORDER BY id DESC LIMIT 1"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        if sqlite3_column_type(stmt, 0) == SQLITE_NULL { return nil }
        return String(cString: sqlite3_column_text(stmt, 0))
    }

    func close() {
        sqlite3_close(db)
        db = nil
    }
}
