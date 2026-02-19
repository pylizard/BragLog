//
//  Tag.swift
//  BragLog
//

import Foundation

struct Tag: Identifiable, Hashable {
    let name: String

    var id: String { name }
}
