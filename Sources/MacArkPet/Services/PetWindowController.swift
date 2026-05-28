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
        model.visualCropRect = nil
        model.visualCropKind = nil
        appliedContactInset = 0
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
        model.visualCropRect = nil
        model.visualCropKind = nil
        appliedContactInset = 0
        resizeForCurrentModel(preserveBottom: true)
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

    private func resizeForCurrentModel(preserveBottom: Bool) {
        if normalizeStandingSizeIfNeeded() {
            return
        }

        let size = PetWindowMetrics.size(
            hasSpineAssets: model.hasSpineAssets,
            renderScale: model.renderScale,
            visualAspectRatio: model.visualAspectRatio,
            visualCropRect: model.visualCropRect
        )
        let newContactInset = model.contactInset(forWindowSize: size)
        guard window.frame.size != size || abs(appliedContactInset - newContactInset) > 0.5 else { return }

        let oldFrame = window.frame
        let origin: NSPoint
        if preserveBottom {
            let contactY = oldFrame.minY + appliedContactInset
            origin = NSPoint(
                x: oldFrame.midX - size.width / 2,
                y: contactY - newContactInset
            )
        } else {
            origin = oldFrame.origin
        }

        window.setFrame(NSRect(origin: origin, size: size), display: true)
        appliedContactInset = newContactInset
        physics.resetOrigin(origin, clearSupport: false)
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
        model.visualCropRect = nil
        model.visualCropKind = nil
        appliedContactInset = 0
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
