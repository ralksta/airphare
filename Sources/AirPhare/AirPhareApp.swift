import AirPhareCore
import AppKit
import SwiftUI

@main
struct AirPhareApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let vm = MonitorViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.action = #selector(handleStatusBarClick(_:))
            button.target = self
            button.imagePosition = .imageLeading
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        self.statusItem = item

        let hosting = NSHostingController(rootView: MenuBarView(vm: vm))
        hosting.sizingOptions = [.preferredContentSize]

        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = true
        pop.contentViewController = hosting
        self.popover = pop

        vm.onMenuBarUpdate = { [weak self] in
            self?.updateStatusButton()
        }
        updateStatusButton()
        vm.startIfNeeded()
    }

    private func updateStatusButton() {
        guard let button = statusItem?.button else { return }

        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let image = NSImage(
            systemSymbolName: vm.menuBarSymbol,
            accessibilityDescription: L10n.t(.menuBarAccessibility, lang: vm.lang)
        )?.withSymbolConfiguration(config)
        image?.isTemplate = true
        button.image = image

        let title = vm.menuBarTitle
        button.title = title.isEmpty ? "" : " \(title)"
        button.toolTip = "AirPhare: \(vm.report.headline)"
    }

    @objc private func handleStatusBarClick(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else {
            togglePopover(sender)
            return
        }

        if event.type == .rightMouseUp || (event.type == .leftMouseUp && event.modifierFlags.contains(.control)) {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            vm.onPopoverOpen()
        }
    }

    private func showContextMenu() {
        guard let item = statusItem, let button = item.button else { return }
        if popover?.isShown == true {
            popover?.performClose(nil)
        }

        let lang = vm.lang
        let menu = NSMenu()

        let header = NSMenuItem(title: "AirPhare — \(vm.report.headline)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let quickCheck = NSMenuItem(title: L10n.t(.btnQuickCheck, lang: lang), action: #selector(menuQuickCheck), keyEquivalent: "r")
        quickCheck.target = self
        menu.addItem(quickCheck)

        let fullBench = NSMenuItem(title: L10n.t(.btnFullBenchmark, lang: lang), action: #selector(menuFullBenchmark), keyEquivalent: "b")
        fullBench.target = self
        menu.addItem(fullBench)

        let rfScan = NSMenuItem(title: L10n.t(.btnChannelScan, lang: lang), action: #selector(menuRFScan), keyEquivalent: "")
        rfScan.target = self
        menu.addItem(rfScan)

        let resetWiFi = NSMenuItem(title: L10n.t(.actionReconnectWiFi, lang: lang), action: #selector(menuReconnectWiFi), keyEquivalent: "")
        resetWiFi.target = self
        menu.addItem(resetWiFi)

        menu.addItem(.separator())

        let openReport = NSMenuItem(title: L10n.t(.menuCopyReport, lang: lang), action: #selector(menuOpenReport), keyEquivalent: "o")
        openReport.target = self
        menu.addItem(openReport)

        let revealLog = NSMenuItem(title: L10n.t(.menuRevealLog, lang: lang), action: #selector(menuRevealLog), keyEquivalent: "l")
        revealLog.target = self
        menu.addItem(revealLog)

        let openRouter = NSMenuItem(title: L10n.t(.actionOpenRouter, lang: lang), action: #selector(menuOpenRouter), keyEquivalent: "")
        openRouter.target = self
        menu.addItem(openRouter)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: L10n.t(.btnQuit, lang: lang), action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        button.performClick(nil)
        item.menu = nil
    }

    @objc private func menuQuickCheck() { Task { await vm.runLightweightCheck() } }
    @objc private func menuFullBenchmark() { Task { await vm.runFullBenchmark() } }
    @objc private func menuRFScan() { Task { await vm.runRFScanOnly() } }
    @objc private func menuReconnectWiFi() { Task { await vm.reconnectWiFi() } }
    @objc private func menuOpenReport() { vm.openHTMLReport() }
    @objc private func menuRevealLog() { vm.openLogFolder() }
    @objc private func menuOpenRouter() { vm.openRouterURL() }
    @objc private func menuQuit() { NSApplication.shared.terminate(nil) }
}
