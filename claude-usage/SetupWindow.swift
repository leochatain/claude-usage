import SwiftUI
import AppKit
import ServiceManagement

private var setupWindowController: NSWindowController?

func showSetupWindow(onSave: @escaping () -> Void, onTogglePercentage: @escaping () -> Void) {
    if let existing = setupWindowController {
        existing.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return
    }

    let view = SetupView(onSave: {
        setupWindowController?.close()
        setupWindowController = nil
        onSave()
    }, onCancel: {
        setupWindowController?.close()
        setupWindowController = nil
    }, onTogglePercentage: onTogglePercentage)

    let hostingController = NSHostingController(rootView: view)
    let window = NSWindow(contentViewController: hostingController)
    window.title = "Claude Usage — Setup"
    window.styleMask = [.titled, .closable]
    window.setContentSize(NSSize(width: 420, height: 290))
    window.center()

    let controller = NSWindowController(window: window)
    setupWindowController = controller
    controller.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
}

private struct SetupView: View {
    @State private var orgId: String = KeychainHelper.load(key: "orgId") ?? ""
    @State private var sessionKey: String = KeychainHelper.load(key: "sessionKey") ?? ""
    @AppStorage("showPercentage") private var showPercentage = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    var onSave: () -> Void
    var onCancel: () -> Void
    var onTogglePercentage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configure Claude Usage")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Organization ID")
                    .font(.callout.weight(.medium))
                TextField("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", text: $orgId)
                    .textFieldStyle(.roundedBorder)
                Text("Go to claude.ai → Settings → Organization. Copy the UUID from the URL.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Session Key")
                    .font(.callout.weight(.medium))
                SecureField("sk-ant-…", text: $sessionKey)
                    .textFieldStyle(.roundedBorder)
                Text("From your browser cookies at claude.ai (starts with sk-ant-).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Toggle("Show percentage in menu bar", isOn: $showPercentage)
                .toggleStyle(.checkbox)
                .font(.callout)
                .onChange(of: showPercentage) { onTogglePercentage() }

            Toggle("Launch at login", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .font(.callout)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    let trimmedOrg = orgId.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedKey = sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedOrg.isEmpty, !trimmedKey.isEmpty else { return }
                    KeychainHelper.save(key: "orgId", value: trimmedOrg)
                    KeychainHelper.save(key: "sessionKey", value: trimmedKey)
                    onSave()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(orgId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || sessionKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 420)
    }
}
