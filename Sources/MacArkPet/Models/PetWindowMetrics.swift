// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 MacArkPet contributors

import AppKit

enum PetWindowMetrics {
    static let minimumRenderScale: CGFloat = 0.1
    static let maximumRenderScale: CGFloat = 6.0

    static func size(
        hasSpineAssets: Bool,
        renderScale: CGFloat,
        visualAspectRatio: CGFloat? = nil,
        visualCropRect: CGRect? = nil
    ) -> NSSize {
        if hasSpineAssets, let visualCropRect, visualCropRect.width > 24, visualCropRect.height > 24 {
            return NSSize(
                width: rounded(min(max(visualCropRect.width, 28), 1_600)),
                height: rounded(min(max(visualCropRect.height, 28), 1_700))
            )
        }

        return stageSize(hasSpineAssets: hasSpineAssets, renderScale: renderScale, visualAspectRatio: visualAspectRatio)
    }

    static func stageSize(hasSpineAssets: Bool, renderScale: CGFloat, visualAspectRatio: CGFloat? = nil) -> NSSize {
        let scale = min(max(renderScale, minimumRenderScale), maximumRenderScale)
        if hasSpineAssets {
            if let visualAspectRatio {
                let aspect = min(max(visualAspectRatio, 0.75), 1.55)
                let height = rounded(min(max(320 * scale, 64), 1_760))
                let width = rounded(min(max(height * aspect, 64), 1_900))
                return NSSize(width: width, height: height)
            }

            return NSSize(
                width: rounded(min(max(320 * scale, 64), 1_900)),
                height: rounded(min(max(320 * scale, 64), 1_760))
            )
        }

        return NSSize(
            width: rounded(min(max(230 * scale, 48), 1_200)),
            height: rounded(min(max(230 * scale, 48), 1_200))
        )
    }

    private static func rounded(_ value: CGFloat) -> CGFloat {
        value.rounded(.toNearestOrAwayFromZero)
    }
}
