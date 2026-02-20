//
//  TagsFieldView.swift
//  BragLog
//

import SwiftUI
import AppKit

struct TagsFieldView: View {
    @Binding var selectedTags: [String]
    let allTags: [Tag]
    var filterText: Binding<String>

    private var availableTagNames: [String] {
        let names = allTags.map(\.name)
        let selectedSet = Set(selectedTags.map { $0.lowercased() })
        return names.filter { !selectedSet.contains($0.lowercased()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !selectedTags.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(selectedTags, id: \.self) { tag in
                        HStack(spacing: 2) {
                            Text(tag)
                                .font(.callout)
                                .lineLimit(1)
                            Button {
                                selectedTags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.2))
                        .clipShape(Capsule())
                    }
                }
            }
            StringDropdownField(
                items: availableTagNames,
                text: filterText,
                placeholder: "Tags",
                onSelect: { tag in
                    selectedTags.append(tag)
                    filterText.wrappedValue = ""
                },
                onCommit: { tag in
                    let t = tag.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty, !selectedTags.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                        selectedTags.append(t)
                    }
                    filterText.wrappedValue = ""
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
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, point) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var positions: [CGPoint] = []
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        let totalHeight = y + rowHeight
        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
