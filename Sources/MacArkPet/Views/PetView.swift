// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 MacArkPet contributors

import SwiftUI

struct PetView: View {
    @ObservedObject var model: PetModel

    var body: some View {
        let bob = model.mood == .sleepy ? 0 : sin(model.animationPhase * 8) * 5
        let windowSize = PetWindowMetrics.size(
            hasSpineAssets: model.hasSpineAssets,
            renderScale: model.renderScale,
            visualAspectRatio: model.visualAspectRatio,
            visualCropRect: model.visualCropRect
        )
        let stageSize = PetWindowMetrics.stageSize(
            hasSpineAssets: model.hasSpineAssets,
            renderScale: model.renderScale,
            visualAspectRatio: model.visualAspectRatio
        )
        let canvasSize = CGSize(width: windowSize.width, height: windowSize.height)
        let cropRect = model.hasSpineAssets ? model.visualCropRect : nil

        ZStack {
            if !model.hasSpineAssets {
                shadow
                    .offset(y: canvasSize.height * 0.33)
            }

            if model.hasSpineAssets {
                ZStack(alignment: .topLeading) {
                    SpinePetWebView(model: model)
                        .frame(width: stageSize.width, height: stageSize.height)
                        .offset(x: -(cropRect?.minX ?? 0), y: -(cropRect?.minY ?? 0))
                }
                .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
                .clipped()
                .transaction { transaction in
                    transaction.animation = nil
                }
            } else if let image = petImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 250, height: 250)
                    .offset(y: bob)
                    .shadow(color: .black.opacity(model.isDragging ? 0.28 : 0.16), radius: model.isDragging ? 18 : 10, y: 8)
            } else {
                let blink = model.mood == .sleepy || Int(model.animationPhase * 2.2) % 9 == 0
                VStack(spacing: 0) {
                    head(blink: blink)
                        .offset(y: bob)
                    bodyShape
                        .offset(y: -20 + bob)
                }
            }
        }
        .scaleEffect(x: model.hasSpineAssets ? 1 : (model.facingLeft ? -1 : 1), y: 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: model.mood)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: model.facingLeft)
        .frame(width: canvasSize.width, height: canvasSize.height)
        .contentShape(Rectangle())
    }

    private var petImage: NSImage? {
        guard let imageURL = model.imageURL else { return nil }
        return NSImage(contentsOf: imageURL)
    }

    private var shadow: some View {
        Ellipse()
            .fill(.black.opacity(model.isDragging ? 0.12 : 0.2))
            .frame(width: model.hasSpineAssets ? max(96, min(190, model.renderScale * 132)) : (model.imageURL == nil ? (model.mood == .sleepy ? 118 : 92) : 150), height: 18)
            .blur(radius: 5)
    }

    private func head(blink: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 42, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.cyan.opacity(0.95), .mint.opacity(0.98), .white.opacity(0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 42, style: .continuous)
                        .stroke(.white.opacity(0.85), lineWidth: 3)
                )
                .shadow(color: .cyan.opacity(model.isDragging ? 0.55 : 0.32), radius: model.isDragging ? 22 : 14)

            cap
                .offset(x: -12, y: -40)

            face(blink: blink)
                .offset(y: 6)
        }
        .frame(width: model.mood == .sleepy ? 138 : 126, height: model.mood == .sleepy ? 92 : 118)
        .rotationEffect(.degrees(model.mood == .sleepy ? -7 : 0))
    }

    private var cap: some View {
        ZStack {
            Capsule()
                .fill(.indigo.opacity(0.9))
                .frame(width: 88, height: 34)
                .rotationEffect(.degrees(-13))

            Capsule()
                .fill(.yellow.opacity(0.85))
                .frame(width: 22, height: 9)
                .offset(x: 12, y: -2)
                .rotationEffect(.degrees(-13))
        }
    }

    private func face(blink: Bool) -> some View {
        HStack(spacing: 24) {
            eye(blink: blink)
            eye(blink: blink)
        }
        .overlay(alignment: .bottom) {
            mouth
                .offset(y: 28)
        }
    }

    private func eye(blink: Bool) -> some View {
        Capsule()
            .fill(.black.opacity(0.78))
            .frame(width: 13, height: blink ? 3 : 20)
    }

    private var mouth: some View {
        Capsule()
            .fill(model.mood == .happy ? .pink.opacity(0.85) : .black.opacity(0.55))
            .frame(width: model.mood == .happy ? 28 : 18, height: model.mood == .happy ? 10 : 5)
    }

    private var bodyShape: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.teal.opacity(0.92))
                .frame(width: 82, height: 70)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.6), lineWidth: 2)
                )

            HStack(spacing: 58) {
                arm(rotation: -24)
                arm(rotation: 24)
            }
            .offset(y: -4)

            HStack(spacing: 28) {
                foot
                foot
            }
            .offset(y: 38)
        }
    }

    private func arm(rotation: Double) -> some View {
        Capsule()
            .fill(.cyan.opacity(0.95))
            .frame(width: 18, height: 48)
            .rotationEffect(.degrees(rotation + (model.mood == .happy ? 12 : 0)))
    }

    private var foot: some View {
        Capsule()
            .fill(.indigo.opacity(0.72))
            .frame(width: 26, height: 14)
    }
}
