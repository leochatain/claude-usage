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
            button.action = #selector(togglePopover)
            button.target = self
        }
        updateIcon(usage: nil)

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
            showSetupWindow(
                onSave: { [weak self] in self?.refresh() },
                onTogglePercentage: { [weak self] in
                    guard let self else { return }
                    self.updateIcon(usage: self.service.sessionUsage)
                }
            )
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
            await MainActor.run {
                updateIcon(usage: service.sessionUsage)
            }
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

    private func updateIcon(usage: Double?) {
        let pct = usage ?? 0
        let variableValue: Double = switch pct {
        case ..<25: 0.0
        case ..<50: 0.34
        case ..<75: 0.67
        default: 1.0
        }
        let image = NSImage(
            systemSymbolName: "chart.bar.fill",
            variableValue: variableValue,
            accessibilityDescription: usage.map { "Claude Usage: \(Int($0))%" } ?? "Claude Usage"
        )
        if UserDefaults.standard.bool(forKey: "showPercentage"), let usage {
            let pctStr = "\(Int(usage))% "
            let attributed = NSMutableAttributedString(
                string: pctStr,
                attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                    .baselineOffset: -0.5
                ]
            )
            statusItem.button?.attributedTitle = attributed
            statusItem.button?.imagePosition = .imageTrailing
        } else {
            statusItem.button?.title = ""
            statusItem.button?.imagePosition = .imageLeading
        }
        statusItem.button?.image = image
    }

    private func openSettings() {
        popover.performClose(nil)
        showSetupWindow(
            onSave: { [weak self] in self?.refresh() },
            onTogglePercentage: { [weak self] in
                guard let self else { return }
                self.updateIcon(usage: self.service.sessionUsage)
            }
        )
    }
}
