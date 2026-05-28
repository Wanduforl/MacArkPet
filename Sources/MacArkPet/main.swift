import AppKit

private enum AppRuntime {
    static let delegate = MainActor.assumeIsolated {
        MacArkPetApp()
    }
}

let app = NSApplication.shared

app.delegate = AppRuntime.delegate
app.setActivationPolicy(.regular)
app.run()
