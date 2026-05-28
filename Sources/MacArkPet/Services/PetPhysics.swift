// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 MacArkPet contributors

import AppKit

struct PetPhysics {
    var gravity: CGFloat = 1_500
    var floorInset: CGFloat = 0
    var windowSurfaceInset: CGFloat = 4
    var horizontalSpeed: CGFloat = 42
    private var preciseOrigin: CGPoint?
    private var currentSupport: Surface?

    private struct Surface {
        enum Kind: Int {
            case floor = 0
            case top = 1
            case bottomEdge = 2
        }

        let windowNumber: Int
        let kind: Kind
        let topY: CGFloat
        let left: CGFloat
        let right: CGFloat
        let rect: CGRect

        var isFloor: Bool {
            kind == .floor
        }
    }

    mutating func resetOrigin(_ origin: CGPoint, clearSupport: Bool = true) {
        preciseOrigin = origin
        if clearSupport {
            currentSupport = nil
        }
    }

    mutating func step(model: PetModel, window: NSWindow, now: Date) {
        let isLeftButtonDown = (NSEvent.pressedMouseButtons & 1) != 0
        let isActivelyDragging = model.isDragging && isLeftButtonDown && now.timeIntervalSince(model.lastDragEventAt) < 0.45
        if model.isDragging && !isActivelyDragging {
            model.isDragging = false
            model.velocity.dy = 0
        }

        let dt = min(max(now.timeIntervalSince(model.lastTick), 0), 1.0 / 20.0)
        model.lastTick = now
        model.animationPhase += CGFloat(dt)

        guard !isActivelyDragging, let screen = window.screen ?? NSScreen.main else {
            preciseOrigin = window.frame.origin
            currentSupport = nil
            return
        }

        var frame = window.frame
        frame.origin = preciseOrigin ?? frame.origin
        let bounds = screen.visibleFrame
        let edgeInset: CGFloat = 2
        let contactInset = model.contactInset(forWindowSize: frame.size)
        var previousContactY = frame.minY + contactInset
        let isStationaryMood = model.mood == .sleepy
            || model.mood == .resting
            || model.mood == .special
            || model.mood == .happy

        if abs(model.velocity.dy) < 1, let support = currentSupport {
            if let updatedSupport = updatedSurface(
                matching: support,
                frame: frame,
                contactInset: contactInset,
                screen: screen,
                petWindowNumber: window.windowNumber
            ) {
                let supportDeltaX = updatedSupport.left - support.left
                let supportDeltaY = updatedSupport.topY - support.topY
                var shiftedFrame = frame
                shiftedFrame.origin.x += supportDeltaX
                shiftedFrame.origin.y += supportDeltaY
                if abs(supportDeltaX) < 96,
                   abs(supportDeltaY) < 96,
                   supportsFeet(of: shiftedFrame, contactInset: contactInset, on: updatedSupport, screen: screen) {
                    frame = shiftedFrame
                    previousContactY = frame.minY + contactInset
                    currentSupport = updatedSupport
                } else {
                    currentSupport = nil
                }
            } else {
                currentSupport = nil
            }
        }

        if isStationaryMood {
            model.velocity.dx *= 0.86
            if abs(model.velocity.dx) < 1 {
                model.velocity.dx = 0
            }
        } else if abs(model.velocity.dx) < horizontalSpeed * 0.35 {
            model.velocity.dx = model.facingLeft ? -horizontalSpeed : horizontalSpeed
        }

        if frame.minX <= bounds.minX + edgeInset {
            frame.origin.x = bounds.minX + edgeInset
            model.velocity.dx = isStationaryMood ? 0 : abs(horizontalSpeed)
        } else if frame.maxX >= bounds.maxX - edgeInset {
            frame.origin.x = bounds.maxX - frame.width - edgeInset
            model.velocity.dx = isStationaryMood ? 0 : -abs(horizontalSpeed)
        }

        model.velocity.dy -= gravity * CGFloat(dt)
        frame.origin.x += model.velocity.dx * CGFloat(dt)
        frame.origin.y += model.velocity.dy * CGFloat(dt)

        let support = landingSurface(
            for: frame,
            contactInset: contactInset,
            previousContactY: previousContactY,
            screen: screen,
            petWindowNumber: window.windowNumber
        )
        let contactY = frame.minY + contactInset
        if model.velocity.dy <= 0, support.isFloor, contactY <= support.topY {
            frame.origin.y = support.topY - contactInset
            model.velocity.dy = 0
            currentSupport = support
        } else if model.velocity.dy <= 0, contactY <= support.topY, previousContactY >= support.topY - 34 {
            frame.origin.y = support.topY - contactInset
            model.velocity.dy = 0
            currentSupport = support
        } else if currentSupport?.isFloor == false, support.isFloor {
            currentSupport = nil
        } else if currentSupport?.isFloor == false, contactY < support.topY - 80 {
            currentSupport = nil
        }

        if frame.minX <= bounds.minX + edgeInset {
            frame.origin.x = bounds.minX + edgeInset
            model.velocity.dx = isStationaryMood ? 0 : abs(horizontalSpeed)
        } else if frame.maxX >= bounds.maxX - edgeInset {
            frame.origin.x = bounds.maxX - frame.width - edgeInset
            model.velocity.dx = isStationaryMood ? 0 : -abs(horizontalSpeed)
        }

        if abs(model.velocity.dx) > 1 {
            model.facingLeft = model.velocity.dx < 0
        }

        if now >= model.nextMoodChange {
            pickNextIdleAction(model: model, onWindowSurface: currentSupport?.isFloor == false)
        }

        preciseOrigin = frame.origin
        window.setFrameOrigin(frame.origin)
    }

    private func pickNextIdleAction(model: PetModel, onWindowSurface: Bool) {
        if model.mood != .idle {
            model.mood = .idle
            if abs(model.velocity.dx) < horizontalSpeed * 0.35 {
                model.velocity.dx = model.facingLeft ? -horizontalSpeed : horizontalSpeed
            }
            model.nextMoodChange = Date().addingTimeInterval(TimeInterval.random(in: 8...14))
            return
        }

        let roll = Int.random(in: 0..<100)
        if roll < 6 {
            model.mood = .sleepy
            model.velocity = CGVector(dx: 0, dy: 0)
            model.nextMoodChange = Date().addingTimeInterval(TimeInterval.random(in: 7...14))
            return
        }
        let sitThreshold = onWindowSurface ? 42 : 16
        if roll < sitThreshold {
            model.mood = .resting
            model.velocity = CGVector(dx: 0, dy: 0)
            model.nextMoodChange = Date().addingTimeInterval(TimeInterval.random(in: onWindowSurface ? 7...14 : 4...8))
            return
        }
        if roll < sitThreshold + 6 {
            model.mood = .special
            model.velocity = CGVector(dx: 0, dy: 0)
            model.nextMoodChange = Date().addingTimeInterval(TimeInterval.random(in: 16...24))
            return
        }

        model.mood = .idle
        if roll > 68 {
            model.velocity.dx *= -1
            model.facingLeft.toggle()
        }
        if abs(model.velocity.dx) < horizontalSpeed * 0.35 {
            model.velocity.dx = model.facingLeft ? -horizontalSpeed : horizontalSpeed
        }
        model.nextMoodChange = Date().addingTimeInterval(TimeInterval.random(in: 8...16))
    }

    private func landingSurface(
        for frame: NSRect,
        contactInset: CGFloat,
        previousContactY: CGFloat,
        screen: NSScreen,
        petWindowNumber: Int
    ) -> Surface {
        let floor = floorSurface(screen: screen)
        let footMinX = frame.minX + frame.width * 0.18
        let footMaxX = frame.maxX - frame.width * 0.18
        let contactY = frame.minY + contactInset
        var best = floor

        for surface in windowSurfaces(screen: screen, petWindowNumber: petWindowNumber) {
            guard footMaxX > surface.left + 12, footMinX < surface.right - 12 else { continue }
            guard surface.topY > best.topY,
                  surface.topY + frame.height - contactInset <= screen.visibleFrame.maxY + 24,
                  surface.topY <= previousContactY + 28,
                  surface.topY >= contactY - 74 else {
                continue
            }
            best = surface
        }

        return best
    }

    private func updatedSurface(
        matching support: Surface,
        frame: NSRect,
        contactInset: CGFloat,
        screen: NSScreen,
        petWindowNumber: Int
    ) -> Surface? {
        if support.isFloor {
            return floorSurface(screen: screen)
        }

        return windowSurfaces(screen: screen, petWindowNumber: petWindowNumber)
            .first { surface in
                surface.windowNumber == support.windowNumber
                    && surface.kind == support.kind
                    && supportsFeet(of: frame, contactInset: contactInset, on: surface, screen: screen)
            }
    }

    private func floorSurface(screen: NSScreen) -> Surface {
        let visible = screen.visibleFrame
        return Surface(
            windowNumber: 0,
            kind: .floor,
            topY: visible.minY + floorInset,
            left: visible.minX,
            right: visible.maxX,
            rect: visible
        )
    }

    private func windowSurfaces(screen: NSScreen, petWindowNumber: Int) -> [Surface] {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return windows.flatMap { info -> [Surface] in
            let number = info[kCGWindowNumber as String] as? Int ?? 0
            if number == petWindowNumber { return [] }

            let alpha = info[kCGWindowAlpha as String] as? Double ?? 1
            guard alpha > 0.05 else { return [] }

            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { return [] }

            guard let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let x = bounds["X"] as? CGFloat,
                  let y = bounds["Y"] as? CGFloat,
                  let width = bounds["Width"] as? CGFloat,
                  let height = bounds["Height"] as? CGFloat,
                  width > 90, height > 40 else {
                return []
            }

            let left = x
            let right = x + width
            let top = screen.frame.maxY - y
            let bottom = top - height
            let rect = CGRect(x: left, y: bottom, width: width, height: height)

            guard rect.intersects(screen.frame),
                  top >= screen.visibleFrame.minY + floorInset,
                  top <= screen.visibleFrame.maxY - 24 else {
                return []
            }

            var surfaces = [
                Surface(windowNumber: number, kind: .top, topY: top - windowSurfaceInset, left: left, right: right, rect: rect)
            ]

            let ledgeY = max(bottom, screen.visibleFrame.minY + floorInset)
            if ledgeY > screen.visibleFrame.minY + 56, ledgeY < screen.visibleFrame.maxY - 120 {
                surfaces.append(Surface(windowNumber: number, kind: .bottomEdge, topY: ledgeY, left: left, right: right, rect: rect))
            }

            return surfaces
        }
    }

    private func supportsFeet(of frame: NSRect, contactInset: CGFloat, on surface: Surface, screen: NSScreen) -> Bool {
        if surface.isFloor { return true }

        let footMinX = frame.minX + frame.width * 0.18
        let footMaxX = frame.maxX - frame.width * 0.18
        guard footMaxX > surface.left + 12, footMinX < surface.right - 12 else {
            return false
        }

        return surface.topY + frame.height - contactInset <= screen.visibleFrame.maxY + 24
    }
}
