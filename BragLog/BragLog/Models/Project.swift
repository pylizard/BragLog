//
//  Project.swift
//  BragLog
//

import Foundation

struct Project: Identifiable, Hashable {
    let name: String

    var id: String { name }
}
