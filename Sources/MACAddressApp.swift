import AppKit
import SwiftUI

@main
struct MACAddressApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let networkStore = NetworkInterfaceStore()
    private let profileStore = ProfileStore()
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isAnotherInstanceRunning else {
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = Self.menuBarIcon
        statusItem.button?.toolTip = "MAC Address"

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        try? networkStore.reload()
        profileStore.reload()
        menu.removeAllItems()

        guard let selected = networkStore.selectedInterface else {
            let empty = NSMenuItem(title: "No Network Interfaces", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            menu.addItem(.separator())
            menu.addItem(quitItem)
            return
        }

        menu.addItem(interfacePicker)
        menu.addItem(detailItem(title: "Current",
                                detail: selected.currentAddress?.displayValue ?? "Unavailable"))
        menu.addItem(.separator())

        let random = NSMenuItem(title: "Randomize Address",
                                action: #selector(useRandomAddress), keyEquivalent: "")
        random.target = self
        menu.addItem(random)

        let custom = NSMenuItem(title: "Set Address…",
                                action: #selector(enterAddress), keyEquivalent: "e")
        custom.target = self
        menu.addItem(custom)

        menu.addItem(profilesItem(for: selected))

        let restore = NSMenuItem(title: "Restore Hardware Address",
                                 action: #selector(restoreHardwareAddress), keyEquivalent: "")
        restore.target = self
        restore.isEnabled = selected.currentAddress != selected.hardwareAddress
        menu.addItem(restore)

        if NetworkInterfaceStore.isWiFi(selected) {
            let settings = NSMenuItem(title: "Private Wi-Fi Settings…",
                                      action: #selector(openWiFiAddressSettings),
                                      keyEquivalent: "")
            settings.target = self
            menu.addItem(settings)
        }

        menu.addItem(.separator())
        menu.addItem(quitItem)
    }

    private var interfacePicker: NSMenuItem {
        let title = networkStore.selectedInterface?.displayName ?? "Interface"
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for interface in networkStore.interfaces {
            let item = NSMenuItem(title: interface.displayName,
                                  action: #selector(selectInterface(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = interface.device
            item.state = interface.device == networkStore.selectedDevice ? .on : .off
            submenu.addItem(item)
        }
        parent.submenu = submenu
        return parent
    }

    private func profilesItem(for interface: NetworkInterface) -> NSMenuItem {
        let parent = NSMenuItem(title: "Profiles", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        if profileStore.profiles.isEmpty {
            let empty = NSMenuItem(title: "No Profiles", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        } else {
            for profile in profileStore.profiles {
                let item = NSMenuItem(title: "\(profile.name) — \(profile.address.displayValue)",
                                      action: #selector(applyProfile(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = profile.id.uuidString
                item.state = profile.device == interface.device && profile.address == interface.currentAddress
                    ? .on : .off
                submenu.addItem(item)
            }
        }

        submenu.addItem(.separator())
        let save = NSMenuItem(title: "Save Current…",
                              action: #selector(saveCurrentProfile), keyEquivalent: "s")
        save.target = self
        save.isEnabled = interface.currentAddress != nil
        submenu.addItem(save)

        if !profileStore.profiles.isEmpty {
            let delete = NSMenuItem(title: "Remove Profile", action: nil, keyEquivalent: "")
            let deleteMenu = NSMenu()
            for profile in profileStore.profiles {
                let item = NSMenuItem(title: profile.name,
                                      action: #selector(deleteProfile(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = profile.id.uuidString
                deleteMenu.addItem(item)
            }
            delete.submenu = deleteMenu
            submenu.addItem(delete)
        }

        parent.submenu = submenu
        return parent
    }

    private func detailItem(title: String, detail: String) -> NSMenuItem {
        let item = NSMenuItem()
        item.isEnabled = false
        item.view = DetailMenuRowView(title: title, detail: detail)
        return item
    }

    private var quitItem: NSMenuItem {
        NSMenuItem(title: "Quit MAC Address",
                   action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc private func selectInterface(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? String else { return }
        networkStore.select(device: device)
    }

    @objc private func openWiFiAddressSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.wifi-settings-extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func useRandomAddress() {
        apply(HardwareAddress.random())
    }

    @objc private func enterAddress() {
        guard let interface = networkStore.selectedInterface else { return }
        let alert = NSAlert()
        alert.messageText = "Enter a MAC address"
        alert.informativeText = "Use six hexadecimal pairs. Multicast addresses are not valid for a network interface."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "02:11:22:33:44:55"
        field.stringValue = interface.currentAddress?.value ?? ""
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let address = HardwareAddress(field.stringValue) else {
            showError(title: "Invalid MAC address",
                      message: "Enter a 12-digit unicast address, such as 02:11:22:33:44:55.")
            return
        }
        apply(address)
    }

    @objc private func restoreHardwareAddress() {
        guard let interface = networkStore.selectedInterface else { return }
        apply(interface.hardwareAddress, to: interface)
    }

    @objc private func applyProfile(_ sender: NSMenuItem) {
        guard let idString = sender.representedObject as? String,
              let id = UUID(uuidString: idString),
              let profile = profileStore.profile(id: id)
        else { return }

        try? networkStore.reload()
        guard let interface = networkStore.interface(device: profile.device) else {
            showError(title: "Interface unavailable",
                      message: "\(profile.hardwarePort) (\(profile.device)) is not connected to this Mac.")
            return
        }
        networkStore.select(device: interface.device)
        apply(profile.address, to: interface)
    }

    @objc private func saveCurrentProfile() {
        guard let interface = networkStore.selectedInterface,
              let address = interface.currentAddress else { return }

        let alert = NSAlert()
        alert.messageText = "Save MAC profile"
        alert.informativeText = "Profiles remember the address and network interface."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "Home, Work, Testing…"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try profileStore.save(name: field.stringValue, address: address, interface: interface)
        } catch {
            showError(title: "Could not save profile", error: error)
        }
    }

    @objc private func deleteProfile(_ sender: NSMenuItem) {
        guard let idString = sender.representedObject as? String,
              let id = UUID(uuidString: idString),
              let profile = profileStore.profile(id: id) else { return }

        let alert = NSAlert()
        alert.messageText = "Delete “\(profile.name)”?"
        alert.informativeText = "This removes the saved profile only. It does not change the current address."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try profileStore.remove(id: id)
        } catch {
            showError(title: "Could not delete profile", error: error)
        }
    }

    private func apply(_ address: HardwareAddress, to requestedInterface: NetworkInterface? = nil) {
        guard let interface = requestedInterface ?? networkStore.selectedInterface else { return }
        guard interface.currentAddress != address else { return }
        do {
            try networkStore.setAddress(address, on: interface)
        } catch NetworkInterfaceError.authorizationCancelled {
            return
        } catch {
            showError(title: "Could not change MAC address", error: error)
        }
    }

    private func showError(title: String, error: Error) {
        showError(title: title, message: error.localizedDescription)
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static var isAnotherInstanceRunning: Bool {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications.contains { app in
            guard app.processIdentifier != currentPID else { return false }
            if app.bundleIdentifier == "org.2xf.mac-address" { return true }
            return app.executableURL?.lastPathComponent == "MACAddress"
        }
    }

    private static let menuBarIcon: NSImage = {
        let image: NSImage
        if let url = Bundle.main.url(forResource: "menubar@2x", withExtension: "png"),
           let loaded = NSImage(contentsOf: url) {
            image = loaded
        } else {
            image = NSImage(systemSymbolName: "network",
                            accessibilityDescription: "MAC Address") ?? NSImage()
        }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }()
}

private final class DetailMenuRowView: NSView {
    private static let rowSize = NSSize(width: 286, height: 24)

    init(title: String, detail: String) {
        super.init(frame: NSRect(origin: .zero, size: Self.rowSize))

        let titleLabel = Self.makeLabel(title)
        let detailLabel = Self.makeLabel(detail)
        detailLabel.alignment = .right
        detailLabel.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize,
                                                            weight: .regular)
        addSubview(titleLabel)
        addSubview(detailLabel)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 34),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            detailLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: detailLabel.leadingAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize { Self.rowSize }
    override var fittingSize: NSSize { Self.rowSize }

    private static func makeLabel(_ string: String) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.font = NSFont.menuFont(ofSize: 0)
        label.textColor = .disabledControlTextColor
        label.lineBreakMode = .byTruncatingTail
        return label
    }
}
