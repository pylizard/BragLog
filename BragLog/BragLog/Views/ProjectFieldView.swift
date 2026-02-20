//
//  ProjectFieldView.swift
//  BragLog
//

import SwiftUI

struct ProjectFieldView: View {
    @Binding var selectedProject: String?
    let allProjects: [Project]

    private var fieldText: Binding<String> {
        Binding(
            get: { selectedProject ?? "" },
            set: { selectedProject = $0.isEmpty ? nil : $0 }
        )
    }

    private var availableProjectNames: [String] {
        allProjects.map(\.name)
    }

    var body: some View {
        StringDropdownField(
            items: availableProjectNames,
            text: fieldText,
            placeholder: "Project",
            keepSelectedValueInField: true,
            onSelect: { name in
                selectedProject = name
            },
            onCommit: { name in
                let t = name.trimmingCharacters(in: .whitespaces)
                selectedProject = t.isEmpty ? nil : t
            }
        )
        .frame(height: 20)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}
