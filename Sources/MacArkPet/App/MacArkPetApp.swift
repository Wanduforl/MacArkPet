import AppKit

@MainActor
final class MacArkPetApp: NSObject, NSApplicationDelegate {
    private let model = PetModel()
    private let store = ArkModelStore()
    private var petController: PetWindowController?
    private var launcherController: LauncherWindowController?
    private var statusItem: NSStatusItem?
    private var launchedModelID: ArkModelItem.ID?
    private var languageObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("MacArkPet applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.regular)

        store.load()
        launcherController = LauncherWindowController(
            store: store,
            onLaunch: { [weak self] item in
                self?.launchPet(model: item)
            },
            onScaleChange: { [weak self] item, scale in
                self?.updatePetScale(model: item, scale: scale)
            }
        )
        launcherController?.show()
        NSApp.activate(ignoringOtherApps: true)

        installStatusItem()
        languageObserver = NotificationCenter.default.addObserver(
            forName: .appLanguageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.launcherController?.updateTitle()
                self?.refreshMenus()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        launcherController?.show()
        return true
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = "AP"
        item.button?.toolTip = "MacArkPet"
        item.menu = makeMenu()
        statusItem = item
    }

    private func makeMenu() -> NSMenu {
        let language = AppLanguage.current
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: L10n.menuOpenLauncher(language), action: #selector(showLauncher), keyEquivalent: "o"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L10n.menuPoke(language), action: #selector(poke), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: L10n.menuSpecialAction(language), action: #selector(specialAction), keyEquivalent: "e"))
        menu.addItem(NSMenuItem(title: L10n.menuRest(language), action: #selector(rest), keyEquivalent: "a"))
        menu.addItem(NSMenuItem(title: L10n.menuSleep(language), action: #selector(sleep), keyEquivalent: "s"))
        menu.addItem(.separator())

        let clickThrough = NSMenuItem(title: L10n.menuClickThrough(language), action: #selector(toggleClickThrough), keyEquivalent: "t")
        clickThrough.state = model.isClickThrough ? .on : .off
        menu.addItem(clickThrough)

        let topmost = NSMenuItem(title: L10n.menuAlwaysOnTop(language), action: #selector(toggleAlwaysOnTop), keyEquivalent: "")
        topmost.state = model.isAlwaysOnTop ? .on : .off
        menu.addItem(topmost)

        menu.addItem(NSMenuItem(title: L10n.menuResetPosition(language), action: #selector(resetPosition), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(languageMenuItem(language: language))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L10n.menuQuit(language), action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }
        return menu
    }

    private func languageMenuItem(language: AppLanguage) -> NSMenuItem {
        let root = NSMenuItem(title: L10n.language(language), action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: L10n.language(language))
        let preferred = AppLanguage.preferred

        for option in AppLanguage.allCases {
            let item = NSMenuItem(title: option.pickerTitle(current: language), action: #selector(setLanguage), keyEquivalent: "")
            item.target = self
            item.representedObject = option.rawValue
            item.state = option == preferred ? .on : .off
            submenu.addItem(item)
        }

        root.submenu = submenu
        return root
    }

    @objc private func poke() {
        model.poke()
    }

    @objc private func specialAction() {
        model.specialAction()
    }

    @objc private func rest() {
        model.rest()
    }

    @objc private func showLauncher() {
        launcherController?.show()
    }

    @objc private func sleep() {
        model.sleep()
    }

    @objc private func toggleClickThrough(_ sender: NSMenuItem) {
        let enabled = !model.isClickThrough
        petController?.setClickThrough(enabled)
        refreshMenus()
    }

    @objc private func toggleAlwaysOnTop(_ sender: NSMenuItem) {
        let enabled = !model.isAlwaysOnTop
        petController?.setAlwaysOnTop(enabled)
        refreshMenus()
    }

    @objc private func resetPosition() {
        petController?.resetPosition()
    }

    @objc private func setLanguage(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String else { return }
        AppLanguage.setPreferredRawValue(rawValue)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func launchPet(model item: ArkModelItem) {
        let controller: PetWindowController
        if let petController {
            controller = petController
        } else {
            let newController = PetWindowController(model: model)
            newController.setContextMenu(makeMenu())
            petController = newController
            controller = newController
        }

        controller.launch(model: item, renderScale: CGFloat(store.scale(for: item)), speed: CGFloat(store.petSpeed))
        launchedModelID = item.id
        store.status = item.hasSpineAssets ? .launchedFull(item.title) : .launchedPet(item.title)
        refreshMenus()
    }

    private func updatePetScale(model item: ArkModelItem, scale: Double) {
        guard launchedModelID == item.id else { return }
        petController?.updateRenderScale(CGFloat(scale))
    }

    private func refreshMenus() {
        statusItem?.menu = makeMenu()
        petController?.setContextMenu(makeMenu())
    }
}
