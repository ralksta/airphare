import AppKit
import AirPhareCore
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
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.imagePosition = .imageLeading
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

    @objc private func togglePopover(_ sender: AnyObject?) {
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
}
