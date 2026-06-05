// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 MacArkPet contributors

import AppKit
import Combine

final class PetModel: ObservableObject {
    enum Mood {
        case idle
        case happy
        case resting
        case sleepy
        case special
    }

    @Published var mood: Mood = .idle
    @Published var isDragging = false
    @Published var isClickThrough = false
    @Published var isAlwaysOnTop = true
    @Published var facingLeft = false
    @Published var animationPhase: CGFloat = 0
    @Published var displayName = "MacArkPet"
    @Published var imageURL: URL?
    @Published var atlasURL: URL?
    @Published var skeletonURL: URL?
    @Published var renderScale: CGFloat = 1.0
    @Published var renderScaleControlsWindow = false
    @Published var visualAspectRatio: CGFloat?
    @Published var visualCropRect: CGRect?
    @Published var visualCropKind: String?

    var velocity = CGVector(dx: 42, dy: 0)
    var nextMoodChange = Date().addingTimeInterval(8)
    var lastTick = Date()
    var lastDragEventAt = Date.distantPast
    var resumeWalkingAt = Date.distantPast
    private var lastPokeAt = Date.distantPast
    private var visualCropRectsByKind: [String: CGRect] = [:]

    var hasSpineAssets: Bool {
        atlasURL != nil && skeletonURL != nil && imageURL != nil
    }

    func poke() {
        let now = Date()
        guard now.timeIntervalSince(lastPokeAt) > 0.9 else { return }
        lastPokeAt = now
        mood = .happy
        velocity = CGVector(dx: 0, dy: 0)
        nextMoodChange = Date().addingTimeInterval(5)
    }

    func rest() {
        mood = .resting
        velocity = CGVector(dx: 0, dy: 0)
        nextMoodChange = Date().addingTimeInterval(10)
    }

    func specialAction() {
        mood = .special
        velocity = CGVector(dx: 0, dy: 0)
        nextMoodChange = Date().addingTimeInterval(22)
    }

    func sleep() {
        mood = .sleepy
        velocity = CGVector(dx: 0, dy: 0)
        nextMoodChange = Date().addingTimeInterval(12)
    }

    func finishOneShotAction(kind: String) {
        let shouldFinish = (kind == "interact" && mood == .happy)
            || (kind == "special" && mood == .special)
        guard shouldFinish else {
            return
        }

        velocity = CGVector(dx: 0, dy: 0)
        resumeWalkingAt = Date().addingTimeInterval(2.0)
        nextMoodChange = Date().addingTimeInterval(TimeInterval.random(in: 8...14))
        mood = .idle
    }

    func animationKind() -> String {
        switch mood {
        case .sleepy:
            return "sleep"
        case .resting:
            return "rest"
        case .special:
            return "special"
        case .happy:
            return "interact"
        case .idle:
            return abs(velocity.dx) > 4 ? "move" : "idle"
        }
    }

    func contactInset(forWindowSize size: CGSize) -> CGFloat {
        guard hasSpineAssets else { return 0 }

        switch animationKind() {
        case "rest":
            return min(max(size.height * 0.18, 14), 46)
        case "sleep":
            if size.width > size.height * 1.25 {
                return min(max(size.height * 0.035, 3), 12)
            }
            return min(max(size.height * 0.16, 12), 42)
        default:
            return min(max(size.height * 0.015, 2), 6)
        }
    }

    func toggleSleep() {
        mood = mood == .sleepy ? .idle : .sleepy
        if mood == .sleepy {
            velocity = CGVector(dx: 0, dy: 0)
        }
        nextMoodChange = Date().addingTimeInterval(mood == .sleepy ? 12 : 6)
    }

    func resetMotion() {
        isDragging = false
        velocity = CGVector(dx: 42, dy: 0)
        resumeWalkingAt = .distantPast
        facingLeft = false
        mood = .idle
        nextMoodChange = Date().addingTimeInterval(TimeInterval.random(in: 10...18))
    }

    func apply(model: ArkModelItem) {
        displayName = model.title
        imageURL = model.imageURL
        atlasURL = model.atlasURL
        skeletonURL = model.skeletonURL
        renderScaleControlsWindow = false
        visualAspectRatio = nil
        resetVisualCrop()
        resetMotion()
    }

    var activeVisualCropRect: CGRect? {
        guard hasSpineAssets else { return nil }
        let kind = animationKind()
        if isStandingKind(kind) {
            return standingVisualCropRect
        }
        if let crop = visualCropRectsByKind[kind] {
            if isOneShotKind(kind), let standingCrop = standingVisualCropRect {
                return crop.union(standingCrop)
            }
            return crop
        }
        return standingVisualCropRect
    }

    var activeVisualAnchorX: CGFloat? {
        guard hasSpineAssets,
              let activeCrop = activeVisualCropRect else {
            return nil
        }

        let anchorCrop = standingVisualCropRect ?? activeCrop
        let anchorX = anchorCrop.midX - activeCrop.minX
        return min(max(anchorX, 0), activeCrop.width)
    }

    func setVisualCrop(kind: String, rect: CGRect) {
        let safeRect = safeVisualCropRect(rect, kind: kind)
        let stableRect = visualCropRectsByKind[kind]?.union(safeRect) ?? safeRect
        visualCropRectsByKind[kind] = stableRect
        visualCropKind = kind
        visualCropRect = stableRect
    }

    func resetVisualCrop() {
        visualCropRectsByKind.removeAll()
        visualCropRect = nil
        visualCropKind = nil
    }

    private var standingVisualCropRect: CGRect? {
        let standingRects = ["move", "idle"].compactMap { visualCropRectsByKind[$0] }
        return union(standingRects)
    }

    private func isStandingKind(_ kind: String) -> Bool {
        kind == "move" || kind == "idle"
    }

    private func isOneShotKind(_ kind: String) -> Bool {
        kind == "interact" || kind == "special"
    }

    private func union(_ rects: [CGRect]) -> CGRect? {
        guard var result = rects.first else { return nil }
        for rect in rects.dropFirst() {
            result = result.union(rect)
        }
        return result
    }

    private func safeVisualCropRect(_ rect: CGRect, kind: String) -> CGRect {
        let topPadding: CGFloat
        let sidePadding: CGFloat
        let bottomPadding: CGFloat

        switch kind {
        case "move", "idle":
            topPadding = max(18, rect.height * 0.08)
            sidePadding = max(8, rect.width * 0.025)
            bottomPadding = max(3, rect.height * 0.015)
        case "rest", "sleep":
            topPadding = max(12, rect.height * 0.045)
            sidePadding = max(10, rect.width * 0.025)
            bottomPadding = max(3, rect.height * 0.015)
        default:
            topPadding = max(14, rect.height * 0.06)
            sidePadding = max(8, rect.width * 0.025)
            bottomPadding = max(3, rect.height * 0.015)
        }

        let left = max(0, rect.minX - sidePadding)
        let top = max(0, rect.minY - topPadding)
        let right = rect.maxX + sidePadding
        let bottom = rect.maxY + bottomPadding
        return CGRect(
            x: left.rounded(.down),
            y: top.rounded(.down),
            width: max(1, (right - left).rounded(.up)),
            height: max(1, (bottom - top).rounded(.up))
        )
    }
}
