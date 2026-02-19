//
//  Log.swift
//  BragLog
//

import Foundation

struct Log: Identifiable, Hashable {
    let id: Int64
    let message: String
    let tags: String?
    let createdAt: Date
}
