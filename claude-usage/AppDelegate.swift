import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let service = UsageService()
    private var refreshTimer: Timer?
    private var fastPollTimer: Timer?

    private enum IconState {
        case normal(usage: Double)
        case paidQuota
        case outOfQuota
        case loading

        var variableValue: Double {
            switch self {
            case .normal(let usage):
                switch usage {
                case ..<25: return 0.0
                case ..<50: return 0.34
                case ..<75: return 0.67
                default: return 1.0
                }
            case .paidQuota, .outOfQuota:
                return 1.0
            case .loading:
                return 0.0
            }
        }

        var symbolConfiguration: NSImage.SymbolConfiguration? {
            switch self {
            case .paidQuota:
                return NSImage.SymbolConfiguration(hierarchicalColor: .orange)
            case .outOfQuota:
                return NSImage.SymbolConfiguration(hierarchicalColor: .systemGray)
            case .normal, .loading:
                return nil
            }
        }

        var accessibilityDescription: String {
            switch self {
            case .normal(let usage):
                return "Claude Usage: \(Int(usage))%"
            case .paidQuota:
                return "Claude Usage: Using paid credits"
            case .outOfQuota:
                return "Claude Usage: Out of quota"
            case .loading:
                return "Claude Usage"
            }
        }

        var percentageText: String? {
            switch self {
            case .normal(let usage):
                return "\(Int(usage))%"
            case .paidQuota, .outOfQuota:
                return "100%"
            case .loading:
                return nil
            }
        }

        var textColor: NSColor {
            switch self {
            case .paidQuota:
                return .orange
            case .outOfQuota:
                return .systemGray
            case .normal, .loading:
                return .labelColor
            }
        }
    }

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

        startSlowPolling()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            refresh()
            startFastPolling()
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

    private func determineIconState() -> IconState {
        guard let sessionUsage = service.sessionUsage else {
            return .loading
        }

        if sessionUsage < 100 {
            return .normal(usage: sessionUsage)
        }

        // Session quota exhausted (>= 100%)
        let extraUsageEnabled = service.extraUsageEnabled ?? false
        let usedCreditsCents = service.usedCreditsCents ?? 0
        let monthlyLimitCents = service.monthlyLimitCents ?? 0

        if extraUsageEnabled && usedCreditsCents < monthlyLimitCents {
            return .paidQuota
        } else {
            return .outOfQuota
        }
    }

    private func updateIcon(usage: Double?) {
        let state = determineIconState()

        // Create base image with variable value
        var image = NSImage(
            systemSymbolName: "chart.bar.fill",
            variableValue: state.variableValue,
            accessibilityDescription: state.accessibilityDescription
        )

        // Apply color configuration if needed
        if let config = state.symbolConfiguration {
            image = image?.withSymbolConfiguration(config)
        }

        // Update percentage text if enabled
        if UserDefaults.standard.bool(forKey: "showPercentage"), let percentageText = state.percentageText {
            let pctStr = "\(percentageText) "
            let attributed = NSMutableAttributedString(
                string: pctStr,
                attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                    .baselineOffset: -0.5,
                    .foregroundColor: state.textColor
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

    private func startFastPolling() {
        refreshTimer?.invalidate()
        fastPollTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        fastPollTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { [weak self] _ in
            self?.startSlowPolling()
        }
    }

    private func startSlowPolling() {
        fastPollTimer?.invalidate()
        fastPollTimer = nil
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.refresh()
        }
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
