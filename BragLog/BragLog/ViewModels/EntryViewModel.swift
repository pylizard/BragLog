//
//  EntryViewModel.swift
//  BragLog
//

import Foundation
import SwiftUI

@MainActor
final class EntryViewModel: ObservableObject {
    @Published var message: String = ""
    @Published var selectedTags: [String] = []
    @Published var allTags: [Tag] = []
    @Published var saveError: String?
    @Published var shouldClosePopover: Bool = false

    private let database: DatabaseService
    private var loadTagsTask: Task<Void, Never>?

    init(database: DatabaseService) {
        self.database = database
    }

    func loadTags() {
        loadTagsTask?.cancel()
        loadTagsTask = Task {
            do {
                let tags = try database.fetchAllTags()
                if !Task.isCancelled {
                    allTags = tags
                }
            } catch {
                if !Task.isCancelled {
                    saveError = (error as? DatabaseError).map { "\($0)" } ?? error.localizedDescription
                }
            }
        }
    }

    var canSave: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func save() {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        saveError = nil
        do {
            try database.saveEntry(message: trimmed, tags: selectedTags.isEmpty ? nil : selectedTags)
            message = ""
            selectedTags = []
            shouldClosePopover = true
        } catch {
            saveError = (error as? DatabaseError).map { "\($0)" } ?? error.localizedDescription
        }
    }

    func clearCloseFlag() {
        shouldClosePopover = false
    }
}
