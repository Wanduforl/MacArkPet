// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 MacArkPet contributors

import AppKit
import Combine
import SwiftUI

final class PetWindowController {
    let model: PetModel
    let window: PetWindow

    private var physics = PetPhysics()
    private var timer: DispatchSourceTimer?
    private var cancellables = Set<AnyCancellable>()
    private var appliedContactInset: CGFloat = 0
    private var requestedRenderScale: CGFloat = 1
    private var autoScaleFactor: CGFloat = 1
    private var targetStandingHeight: CGFloat = 180
    private var normalizationAttempts = 0
    private var pendingShrinkResize: DispatchWorkItem?
    private var appliedVisualAnchorX: CGFloat?

    init(model: PetModel) {
        self.model = model

        let startFrame = NSRect(x: 240, y: 240, width: 280, height: 280)
        window = PetWindow(
            contentRect: startFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.petModel = model
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .statusBar
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.contentView = NSHostingView(rootView: PetView(model: model))
        window.orderOut(nil)

        model.$visualAspectRatio
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.resizeForCurrentModel(preserveBottom: true)
            }
            .store(in: &cancellables)

        model.$visualCropRect
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.resizeForCurrentModel(preserveBottom: true)
            }
            .store(in: &cancellables)

        model.$mood
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.resizeForCurrentModel(preserveBottom: true)
            }
            .store(in: &cancellables)
    }

    func show() {
        model.isDragging = false
        model.lastTick = Date()
        model.lastDragEventAt = .distantPast
        window.ignoresPetMouseEventsUntil = Date().addingTimeInterval(0.35)
        placeWhereItIsEasyToNotice()
        physics.resetOrigin(window.frame.origin)
        window.orderFrontRegardless()
        startLoop()
    }

    func setContextMenu(_ menu: NSMenu) {
        window.contextMenu = menu
    }

    func setClickThrough(_ enabled: Bool) {
        model.isClickThrough = enabled
        window.ignoresMouseEvents = enabled
    }

    func setAlwaysOnTop(_ enabled: Bool) {
        model.isAlwaysOnTop = enabled
        window.level = enabled ? .statusBar : .normal
    }

    func resetPosition() {
        model.resetMotion()
        resizeForCurrentModel(preserveBottom: true)
        placeWhereItIsEasyToNotice()
        physics.resetOrigin(window.frame.origin)
        window.orderFrontRegardless()
    }

    func launch(model item: ArkModelItem, renderScale: CGFloat, speed: CGFloat) {
        physics.horizontalSpeed = speed
        model.apply(model: item)
        model.renderScaleControlsWindow = true
        model.resetVisualCrop()
        appliedContactInset = 0
        appliedVisualAnchorX = nil
        pendingShrinkResize?.cancel()
        pendingShrinkResize = nil
        requestedRenderScale = renderScale
        autoScaleFactor = 1
        normalizationAttempts = 0
        targetStandingHeight = item.normalizedStandingHeight
        model.renderScale = effectiveRenderScale
        model.velocity.dx = model.facingLeft ? -speed : speed
        resizeForCurrentModel(preserveBottom: true)
        show()
    }

    func updateRenderScale(_ renderScale: CGFloat) {
        guard model.imageURL != nil else { return }
        requestedRenderScale = renderScale
        normalizationAttempts = 3
        model.renderScale = effectiveRenderScale
        model.resetVisualCrop()
        appliedContactInset = 0
        appliedVisualAnchorX = nil
        pendingShrinkResize?.cancel()
        pendingShrinkResize = nil
        resizeForCurrentModel(preserveBottom: true, allowDelayedShrink: false)
    }

    private func startLoop() {
        timer?.cancel()
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(4))
        source.setEventHandler { [weak self] in
            guard let self else { return }
            self.physics.step(model: self.model, window: self.window, now: Date())
        }
        timer = source
        source.resume()
    }

    private func resizeForCurrentModel(preserveBottom: Bool, allowDelayedShrink: Bool = true) {
        if normalizeStandingSizeIfNeeded() {
            return
        }

        let size = PetWindowMetrics.size(
            hasSpineAssets: model.hasSpineAssets,
            renderScale: model.renderScale,
            visualAspectRatio: model.visualAspectRatio,
            visualCropRect: model.activeVisualCropRect
        )
        let newContactInset = model.contactInset(forWindowSize: size)
        let sizeChanged = window.frame.size != size
        let contactInsetChanged = abs(appliedContactInset - newContactInset) > 0.5
        guard sizeChanged || contactInsetChanged else { return }

        if !sizeChanged {
            appliedContactInset = newContactInset
            appliedVisualAnchorX = model.activeVisualAnchorX ?? window.frame.width / 2
            physics.resetOrigin(window.frame.origin, clearSupport: false)
            return
        }

        let oldFrame = window.frame
        if allowDelayedShrink, shouldDelayShrink(from: oldFrame.size, to: size) {
            let transitionSize = NSSize(
                width: max(oldFrame.width, size.width),
                height: max(oldFrame.height, size.height)
            )
            if transitionSize.width > oldFrame.width + 0.5 || transitionSize.height > oldFrame.height + 0.5 {
                applyResize(
                    size: transitionSize,
                    contactInset: model.contactInset(forWindowSize: transitionSize),
                    preserveBottom: preserveBottom
                )
            }
            scheduleDelayedShrinkResize(preserveBottom: preserveBottom)
            return
        }

        pendingShrinkResize?.cancel()
        pendingShrinkResize = nil
        applyResize(size: size, contactInset: newContactInset, preserveBottom: preserveBottom)
    }

    private func applyResize(size: NSSize, contactInset newContactInset: CGFloat, preserveBottom: Bool) {
        let oldFrame = window.frame
        let oldAnchorX = oldFrame.minX + (appliedVisualAnchorX ?? oldFrame.width / 2)
        let newAnchorX = model.activeVisualAnchorX ?? size.width / 2
        let origin: NSPoint
        if preserveBottom {
            let contactY = oldFrame.minY + appliedContactInset
            origin = NSPoint(
                x: oldAnchorX - newAnchorX,
                y: contactY - newContactInset
            )
        } else {
            origin = NSPoint(x: oldAnchorX - newAnchorX, y: oldFrame.minY)
        }

        window.setFrame(NSRect(origin: origin, size: size), display: true)
        appliedContactInset = newContactInset
        appliedVisualAnchorX = newAnchorX
        physics.resetOrigin(origin, clearSupport: false)
    }

    private func shouldDelayShrink(from oldSize: NSSize, to newSize: NSSize) -> Bool {
        guard model.hasSpineAssets,
              model.activeVisualCropRect != nil else {
            return false
        }
        if Date() < model.resumeWalkingAt {
            return false
        }

        let widthIsShrinking = newSize.width < oldSize.width - 2
        let heightIsShrinking = newSize.height < oldSize.height - 2
        guard widthIsShrinking || heightIsShrinking else {
            return false
        }

        let oldArea = max(oldSize.width * oldSize.height, 1)
        let newArea = max(newSize.width * newSize.height, 1)
        let widthRatio = newSize.width / max(oldSize.width, 1)
        let heightRatio = newSize.height / max(oldSize.height, 1)
        return widthRatio < 0.92 || heightRatio < 0.92 || newArea / oldArea < 0.86
    }

    private func scheduleDelayedShrinkResize(preserveBottom: Bool) {
        pendingShrinkResize?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.resizeForCurrentModel(preserveBottom: preserveBottom, allowDelayedShrink: false)
        }
        pendingShrinkResize = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65, execute: workItem)
    }

    private var effectiveRenderScale: CGFloat {
        min(
            max(requestedRenderScale * autoScaleFactor, PetWindowMetrics.minimumRenderScale),
            PetWindowMetrics.maximumRenderScale
        )
    }

    private func normalizeStandingSizeIfNeeded() -> Bool {
        guard model.hasSpineAssets,
              normalizationAttempts < 3,
              model.visualCropKind == "move",
              let crop = model.visualCropRect,
              crop.height > 24 else {
            return false
        }

        let ratio = targetStandingHeight / crop.height
        guard ratio.isFinite, abs(ratio - 1) > 0.08 else {
            normalizationAttempts = 3
            return false
        }

        let nextFactor = min(max(autoScaleFactor * ratio, 0.18), 5.5)
        let nextRenderScale = min(
            max(requestedRenderScale * nextFactor, PetWindowMetrics.minimumRenderScale),
            PetWindowMetrics.maximumRenderScale
        )
        guard abs(nextRenderScale - model.renderScale) > 0.015 else {
            normalizationAttempts = 3
            return false
        }

        autoScaleFactor = nextFactor
        normalizationAttempts += 1
        model.renderScale = nextRenderScale
        model.resetVisualCrop()
        appliedContactInset = 0
        appliedVisualAnchorX = nil
        resizeForCurrentModel(preserveBottom: true)
        return true
    }

    private func placeWhereItIsEasyToNotice() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        window.setFrameOrigin(NSPoint(
            x: visible.midX - window.frame.width / 2,
            y: visible.minY + max(120, visible.height * 0.28)
        ))
    }
}

private extension ArkModelItem {
    var normalizedStandingHeight: CGFloat {
        if type == "Enemy" || tags.contains(where: { $0.hasPrefix("Enemy") }) {
            return 190
        }
        if type == "DynIllust" || tags.contains("DynIllust") {
            return 190
        }
        return 180
    }
}
