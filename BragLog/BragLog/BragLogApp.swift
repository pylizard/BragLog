//
//  BragLogApp.swift
//  BragLog
//
//  Created by Ilya Andrutskiy on 17.02.26.
//

import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

@main
enum BragLogMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}

final class AppStore {
    private(set) var entryViewModel: EntryViewModel?
    private(set) var databaseError: String?
    private var database: DatabaseService?

    @MainActor
    init() {
        do {
            let db = try DatabaseService()
            database = db
            entryViewModel = EntryViewModel(database: db)
        } catch {
            databaseError = (error as? DatabaseError)?.description ?? error.localizedDescription
        }
    }

    @MainActor
    func presentImport() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "db") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try database?.importDatabase(from: url)
            entryViewModel?.loadTags()
            let alert = NSAlert()
            alert.messageText = "Database imported successfully"
            alert.alertStyle = .informational
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Import failed"
            alert.informativeText = (error as? DatabaseError)?.description ?? error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var appStore: AppStore!
    private var closeSubscription: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            appStore = AppStore()
            setupEditMenu()
            setupStatusBar()
            setupPopover()

            closeSubscription = appStore.entryViewModel?.$shouldClosePopover
                .receive(on: RunLoop.main)
                .sink { [weak self] shouldClose in
                    guard shouldClose else { return }
                    self?.appStore.entryViewModel?.clearCloseFlag()
                    self?.popover?.performClose(nil)
                }
        }
    }

    private func setupEditMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(named: "StatusBarIcon")
            button.image?.size = NSSize(width: 22, height: 22)
        }

        let menu = NSMenu()

        let newEntry = NSMenuItem(title: "Log", action: #selector(togglePopover), keyEquivalent: "l")
        newEntry.target = self
        menu.addItem(newEntry)

        let importItem = NSMenuItem(title: "Import DB", action: #selector(importDatabase), keyEquivalent: "")
        importItem.target = self
        menu.addItem(importItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient

        if let vm = appStore.entryViewModel {
            popover.contentViewController = NSHostingController(rootView: EntryView(viewModel: vm))
        } else {
            let errorView = PopoverErrorView(errorMessage: appStore.databaseError)
            popover.contentViewController = NSHostingController(rootView: errorView)
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async { [weak self] in
                self?.showPopoverAnchoredToStatusItem()
            }
        }
    }

    private func showPopoverAnchoredToStatusItem() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let popoverWindow = self.popover.contentViewController?.view.window else { return }

            let buttonRectInWindow = button.convert(button.bounds, to: nil)
            let buttonRectOnScreen = buttonWindow.convertToScreen(buttonRectInWindow)

            var frame = popoverWindow.frame
            frame.origin.x = buttonRectOnScreen.midX - frame.size.width / 2
            frame.origin.y = buttonRectOnScreen.minY - frame.size.height - 4

            if let screen = buttonWindow.screen {
                let visible = screen.visibleFrame
                frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)
                frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)
            }

            popoverWindow.setFrame(frame, display: true)
        }
    }

    @objc private func importDatabase() {
        MainActor.assumeIsolated {
            appStore.presentImport()
        }
    }
}

private struct PopoverErrorView: View {
    let errorMessage: String?

    var body: some View {
        VStack(spacing: 8) {
            Text("Database unavailable")
            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(width: 280)
    }
}
