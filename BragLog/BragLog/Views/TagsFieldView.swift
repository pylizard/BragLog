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
            TagDropdownField(
                items: availableTagNames,
                text: filterText,
                placeholder: "Optional tags",
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

private struct TagDropdownField: NSViewRepresentable {
    var items: [String]
    @Binding var text: String
    var placeholder: String
    var onSelect: (String) -> Void
    var onCommit: (String) -> Void

    @available(macOS 13.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: FieldContainerView, context: Context) -> CGSize? {
        let fitting = nsView.fittingSize
        return CGSize(
            width: proposal.width ?? fitting.width,
            height: proposal.height ?? fitting.height
        )
    }

    func makeNSView(context: Context) -> FieldContainerView {
        let container = FieldContainerView()

        container.textField.placeholderString = placeholder
        container.textField.isEditable = true
        container.textField.isBordered = false
        container.textField.isBezeled = false
        container.textField.drawsBackground = false
        container.textField.focusRingType = .none
        container.textField.delegate = context.coordinator
        container.textField.alignment = .left

        container.button.isBordered = false
        container.button.bezelStyle = .regularSquare
        container.button.image = NSImage(
            systemSymbolName: "chevron.down",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(.init(pointSize: 11, weight: .semibold))
        container.button.imagePosition = .imageOnly
        container.button.contentTintColor = .controlAccentColor
        container.button.target = context.coordinator
        container.button.action = #selector(Coordinator.toggleDropdown(_:))

        let click = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.textFieldClicked(_:)))
        container.textField.addGestureRecognizer(click)

        context.coordinator.attach(container: container)
        context.coordinator.allItems = items
        context.coordinator.refilter(query: text)

        return container
    }

    func updateNSView(_ container: FieldContainerView, context: Context) {
        let coord = context.coordinator
        let oldItems = coord.allItems
        coord.allItems = items

        if container.textField.currentEditor() == nil {
            if oldItems != items {
                coord.refilter(query: container.textField.stringValue)
            }
            if container.textField.stringValue != text {
                container.textField.stringValue = text
                coord.refilter(query: text)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class FieldContainerView: NSView {
        let textField = NSTextField()
        let button = NSButton()
        private let separator = NSView()

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)

            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
            layer?.borderWidth = 0

            textField.translatesAutoresizingMaskIntoConstraints = false
            button.translatesAutoresizingMaskIntoConstraints = false
            separator.translatesAutoresizingMaskIntoConstraints = false
            separator.wantsLayer = true
            separator.layer?.backgroundColor = NSColor.separatorColor.cgColor

            addSubview(textField)
            addSubview(separator)
            addSubview(button)

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
                textField.topAnchor.constraint(equalTo: topAnchor, constant: 1),
                textField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),

                separator.leadingAnchor.constraint(equalTo: textField.trailingAnchor, constant: 6),
                separator.widthAnchor.constraint(equalToConstant: 1),
                separator.topAnchor.constraint(equalTo: topAnchor, constant: 4),
                separator.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),

                button.leadingAnchor.constraint(equalTo: separator.trailingAnchor, constant: 2),
                button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
                button.topAnchor.constraint(equalTo: topAnchor, constant: 1),
                button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
                button.widthAnchor.constraint(equalToConstant: 24)
            ])
        }

        required init?(coder: NSCoder) {
            nil
        }
    }

    class Coordinator: NSObject, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
        var parent: TagDropdownField
        var allItems: [String] = []
        var filteredItems: [String] = []
        private weak var container: FieldContainerView?
        private var dropdownPanel: NSPanel?
        private var tableView: NSTableView?
        private var scrollView: NSScrollView?
        private var localMouseDownMonitor: Any?
        private var globalMouseDownMonitor: Any?

        init(parent: TagDropdownField) {
            self.parent = parent
        }

        deinit {
            closeDropdown()
        }

        func attach(container: FieldContainerView) {
            self.container = container
        }

        func refilter(query: String) {
            let q = query.trimmingCharacters(in: .whitespaces).lowercased()
            filteredItems = q.isEmpty ? allItems : allItems.filter { $0.lowercased().contains(q) }
            tableView?.reloadData()
            resizeDropdownToFitContent()
        }

        @objc func toggleDropdown(_ sender: Any?) {
            if dropdownPanel?.isVisible == true {
                closeDropdown()
            } else {
                openDropdown()
            }
        }

        @objc func textFieldClicked(_ recognizer: NSClickGestureRecognizer) {
            openDropdown()
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            parent.text = textField.stringValue
            refilter(query: textField.stringValue)
            openDropdown()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if dropdownPanel?.isVisible == true, let table = tableView {
                    let row = table.selectedRow
                    if row >= 0, row < filteredItems.count {
                        commitSelection(filteredItems[row])
                        return true
                    }
                }

                let value = control.stringValue.trimmingCharacters(in: .whitespaces)
                if !value.isEmpty {
                    commitFreeform(value)
                    return true
                }
                closeDropdown()
                return true
            }

            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                moveSelection(delta: -1)
                return true
            }

            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                moveSelection(delta: 1)
                return true
            }

            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                if dropdownPanel?.isVisible == true {
                    closeDropdown()
                    return true
                }
                return false
            }

            return false
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            filteredItems.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let value = filteredItems[row]
            let identifier = NSUserInterfaceItemIdentifier("TagCell")
            let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView ?? {
                let v = NSTableCellView()
                v.identifier = identifier
                let label = NSTextField(labelWithString: "")
                label.translatesAutoresizingMaskIntoConstraints = false
                v.addSubview(label)
                v.textField = label
                NSLayoutConstraint.activate([
                    label.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 0),
                    label.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: 0),
                    label.topAnchor.constraint(equalTo: v.topAnchor, constant: 0),
                    label.bottomAnchor.constraint(lessThanOrEqualTo: v.bottomAnchor, constant: 0)
                ])
                return v
            }()
            cell.textField?.stringValue = value
            return cell
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let table = notification.object as? NSTableView else { return }
            let row = table.selectedRow
            if row >= 0, row < filteredItems.count, dropdownPanel?.isVisible == true {
                parent.text = filteredItems[row]
                container?.textField.stringValue = filteredItems[row]
            }
        }

        @objc func tableViewSingleClick(_ sender: Any?) {
            guard let event = NSApp.currentEvent else { return }
            guard event.type == .leftMouseUp || event.type == .leftMouseDown else { return }
            guard let table = tableView else { return }
            let row = table.clickedRow >= 0 ? table.clickedRow : table.selectedRow
            guard row >= 0, row < filteredItems.count else { return }
            commitSelection(filteredItems[row])
        }

        @objc func tableViewDoubleClick(_ sender: Any?) {
            guard let table = tableView else { return }
            let row = table.clickedRow >= 0 ? table.clickedRow : table.selectedRow
            guard row >= 0, row < filteredItems.count else { return }
            commitSelection(filteredItems[row])
        }

        private func moveSelection(delta: Int) {
            openDropdown()
            guard let table = tableView, !filteredItems.isEmpty else { return }
            let current = table.selectedRow >= 0 ? table.selectedRow : -1
            let next = min(max(current + delta, 0), filteredItems.count - 1)
            table.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
            table.scrollRowToVisible(next)
        }

        private func commitSelection(_ value: String) {
            parent.onSelect(value)
            clearAndClose()
        }

        private func commitFreeform(_ value: String) {
            parent.onCommit(value)
            clearAndClose()
        }

        private func clearAndClose() {
            DispatchQueue.main.async {
                self.container?.textField.stringValue = ""
                self.parent.text = ""
                self.refilter(query: "")
            }
            closeDropdown()
        }

        private func openDropdown() {
            guard let container else { return }

            if dropdownPanel == nil {
                let panel = NSPanel(
                    contentRect: .zero,
                    styleMask: [.nonactivatingPanel, .borderless],
                    backing: .buffered,
                    defer: false
                )
                panel.isFloatingPanel = true
                panel.level = .floating
                panel.hasShadow = true
                panel.backgroundColor = .clear
                panel.isOpaque = false
                panel.hidesOnDeactivate = false

                let scroll = NSScrollView()
                scroll.drawsBackground = false
                scroll.hasVerticalScroller = true
                scroll.autohidesScrollers = true
                scroll.borderType = .noBorder
                scroll.contentInsets = NSEdgeInsets(top: 5, left: 10, bottom: 0, right: 0)
                if #available(macOS 11.0, *) {
                    scroll.automaticallyAdjustsContentInsets = false
                }

                let table = NSTableView()
                if #available(macOS 11.0, *) {
                    table.style = .plain
                }
                table.headerView = nil
                table.rowHeight = 18
                table.intercellSpacing = NSSize(width: 0, height: 0)
                table.allowsMultipleSelection = false
                table.allowsEmptySelection = true
                table.selectionHighlightStyle = .regular
                table.target = self
                table.action = #selector(tableViewSingleClick(_:))
                table.doubleAction = #selector(tableViewDoubleClick(_:))
                table.delegate = self
                table.dataSource = self

                let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Tag"))
                column.resizingMask = .autoresizingMask
                table.addTableColumn(column)

                scroll.documentView = table

                let roundedContainer = NSView()
                roundedContainer.wantsLayer = true
                roundedContainer.layer?.cornerRadius = 6
                roundedContainer.layer?.borderWidth = 1
                roundedContainer.layer?.borderColor = NSColor.separatorColor.cgColor
                roundedContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
                roundedContainer.layer?.masksToBounds = true
                roundedContainer.addSubview(scroll)
                scroll.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    scroll.leadingAnchor.constraint(equalTo: roundedContainer.leadingAnchor),
                    scroll.trailingAnchor.constraint(equalTo: roundedContainer.trailingAnchor),
                    scroll.topAnchor.constraint(equalTo: roundedContainer.topAnchor),
                    scroll.bottomAnchor.constraint(equalTo: roundedContainer.bottomAnchor)
                ])
                panel.contentView = roundedContainer

                dropdownPanel = panel
                tableView = table
                scrollView = scroll
            }

            if dropdownPanel?.isVisible == true {
                resizeDropdownToFitContent()
                return
            }

            refilter(query: container.textField.stringValue)
            dropdownPanel?.contentView?.layoutSubtreeIfNeeded()
            tableView?.reloadData()
            resizeDropdownToFitContent()

            guard let parentWindow = container.window, let panel = dropdownPanel else { return }

            let anchorInWindow = container.convert(container.bounds, to: nil)
            let anchorOnScreen = parentWindow.convertToScreen(anchorInWindow)
            let panelFrame = dropdownFrame(anchorOnScreen: anchorOnScreen, width: anchorOnScreen.width)

            panel.setFrame(panelFrame, display: true)
            parentWindow.addChildWindow(panel, ordered: .above)
            panel.orderFront(nil)

            installOutsideClickMonitors(anchorOnScreen: anchorOnScreen)
        }

        private func closeDropdown() {
            uninstallOutsideClickMonitors()
            guard let panel = dropdownPanel else { return }
            if let parentWindow = container?.window {
                parentWindow.removeChildWindow(panel)
            }
            panel.orderOut(nil)
        }

        private func resizeDropdownToFitContent() {
            guard let panel = dropdownPanel else { return }
            guard let container else { return }
            guard let parentWindow = container.window else { return }

            let anchorInWindow = container.convert(container.bounds, to: nil)
            let anchorOnScreen = parentWindow.convertToScreen(anchorInWindow)
            let frame = dropdownFrame(anchorOnScreen: anchorOnScreen, width: anchorOnScreen.width)
            panel.setFrame(frame, display: true)
        }

        private func dropdownFrame(anchorOnScreen: CGRect, width: CGFloat) -> CGRect {
            let rowHeight: CGFloat = 22
            let maxVisibleRows: CGFloat = 10
            let height = max(44, min(maxVisibleRows * rowHeight, CGFloat(filteredItems.count) * rowHeight))
            let gap: CGFloat = 4

            var origin = CGPoint(x: anchorOnScreen.minX, y: anchorOnScreen.minY - gap - height)
            if let screen = container?.window?.screen {
                let visible = screen.visibleFrame
                if origin.y < visible.minY {
                    origin.y = min(anchorOnScreen.maxY + gap, visible.maxY - height)
                }
                origin.x = min(max(origin.x, visible.minX), visible.maxX - width)
            }

            return CGRect(x: origin.x, y: origin.y, width: width, height: height)
        }

        private func installOutsideClickMonitors(anchorOnScreen: CGRect) {
            uninstallOutsideClickMonitors()

            localMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                self?.handleMouseDown(event: event, anchorOnScreen: anchorOnScreen, isGlobal: false)
                return event
            }

            globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                self?.handleMouseDown(event: event, anchorOnScreen: anchorOnScreen, isGlobal: true)
            }
        }

        private func uninstallOutsideClickMonitors() {
            if let localMouseDownMonitor {
                NSEvent.removeMonitor(localMouseDownMonitor)
                self.localMouseDownMonitor = nil
            }
            if let globalMouseDownMonitor {
                NSEvent.removeMonitor(globalMouseDownMonitor)
                self.globalMouseDownMonitor = nil
            }
        }

        private func handleMouseDown(event: NSEvent, anchorOnScreen: CGRect, isGlobal: Bool) {
            guard dropdownPanel?.isVisible == true, let panel = dropdownPanel else { return }

            let mouseOnScreen: CGPoint
            if isGlobal {
                mouseOnScreen = NSEvent.mouseLocation
            } else {
                if let window = event.window {
                    mouseOnScreen = window.convertToScreen(CGRect(origin: event.locationInWindow, size: .zero)).origin
                } else {
                    mouseOnScreen = NSEvent.mouseLocation
                }
            }

            if panel.frame.contains(mouseOnScreen) || anchorOnScreen.contains(mouseOnScreen) {
                return
            }

            closeDropdown()
        }
    }
}

