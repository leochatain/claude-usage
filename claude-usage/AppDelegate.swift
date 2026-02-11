import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let service = UsageService()
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "Claude Usage")
            button.action = #selector(togglePopover)
            button.target = self
        }

        let usageView = UsageView(
            service: service,
            onRefresh: { [weak self] in self?.refresh() },
            onSettings: { [weak self] in self?.openSettings() },
            onQuit: { NSApp.terminate(nil) }
        )
        let hostingController = NSHostingController(rootView: usageView)

        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 200)
        popover.behavior = .transient
        popover.contentViewController = hostingController

        if KeychainHelper.load(key: "sessionKey") == nil || KeychainHelper.load(key: "orgId") == nil {
            showSetupWindow { [weak self] in self?.refresh() }
        } else {
            refresh()
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func refresh() {
        guard let sessionKey = KeychainHelper.load(key: "sessionKey"),
              let orgId = KeychainHelper.load(key: "orgId") else { return }
        Task {
            await service.fetchUsage(sessionKey: sessionKey, orgId: orgId)
        }
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func openSettings() {
        popover.performClose(nil)
        showSetupWindow { [weak self] in self?.refresh() }
    }
}
