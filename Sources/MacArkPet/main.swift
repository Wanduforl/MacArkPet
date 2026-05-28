// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 MacArkPet contributors

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
