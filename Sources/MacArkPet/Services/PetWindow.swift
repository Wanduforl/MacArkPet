// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 MacArkPet contributors

import AppKit

final class PetWindow: NSWindow {
    weak var petModel: PetModel?
    var contextMenu: NSMenu?
    var ignoresPetMouseEventsUntil = Date.distantPast

    private var dragStartLocation: NSPoint = .zero
    private var dragStartOrigin: NSPoint = .zero
    private var didDrag = false
    private var lastClickDate = Date.distantPast

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if Date() < ignoresPetMouseEventsUntil {
            return
        }

        switch event.type {
        case .leftMouseDown:
            didDrag = false
            dragStartLocation = NSEvent.mouseLocation
            dragStartOrigin = frame.origin
            petModel?.lastDragEventAt = Date()

        case .leftMouseDragged:
            let current = NSEvent.mouseLocation
            let dx = current.x - dragStartLocation.x
            let dy = current.y - dragStartLocation.y
            if didDrag || hypot(dx, dy) > 4 {
                didDrag = true
                petModel?.isDragging = true
                petModel?.lastDragEventAt = Date()
                setFrameOrigin(NSPoint(x: dragStartOrigin.x + dx, y: dragStartOrigin.y + dy))
            }

        case .leftMouseUp:
            if !didDrag {
                let now = Date()
                if now.timeIntervalSince(lastClickDate) > 0.28 {
                    petModel?.poke()
                    lastClickDate = now
                }
            }
            petModel?.isDragging = false
            petModel?.velocity.dy = 0

        case .rightMouseDown:
            if let contextMenu, let contentView {
                NSMenu.popUpContextMenu(contextMenu, with: event, for: contentView)
            } else {
                super.sendEvent(event)
            }

        default:
            super.sendEvent(event)
        }
    }
}
