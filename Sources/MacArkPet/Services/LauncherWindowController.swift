import AppKit
import SwiftUI

final class LauncherWindowController {
    let window: NSWindow

    init(
        store: ArkModelStore,
        onLaunch: @escaping (ArkModelItem) -> Void,
        onScaleChange: @escaping (ArkModelItem, Double) -> Void
    ) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        updateTitle()
        window.minSize = NSSize(width: 720, height: 460)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: LauncherView(store: store, onLaunch: onLaunch, onScaleChange: onScaleChange))
    }

    func updateTitle() {
        window.title = L10n.launcherTitle()
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
}
