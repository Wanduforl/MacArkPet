// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 MacArkPet contributors

import SwiftUI
import WebKit

struct SpinePetWebView: NSViewRepresentable {
    @ObservedObject var model: PetModel

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "pet")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.wantsLayer = true
        webView.layer?.backgroundColor = NSColor.clear.cgColor
        webView.layer?.isOpaque = false
        context.coordinator.webView = webView
        context.coordinator.reloadIfNeeded(model)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.reloadIfNeeded(model)
        context.coordinator.syncAnimation(model)
        context.coordinator.syncScale(model)
        context.coordinator.syncFacing(model)
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "pet")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?

        private var loadedAssetKey: String?
        private var isReady = false
        private var lastAnimationKind = ""
        private var lastScale: CGFloat = 0
        private var lastScaleAffectsCamera: Bool?
        private var lastFacingLeft: Bool?
        private weak var currentModel: PetModel?

        func reloadIfNeeded(_ model: PetModel) {
            currentModel = model
            guard let webView, model.hasSpineAssets else { return }

            let assetKey = [model.skeletonURL?.path, model.atlasURL?.path, model.imageURL?.path]
                .compactMap { $0 }
                .joined(separator: "|")
            guard assetKey != loadedAssetKey else { return }

            do {
                let document = try SpineRendererDocument.make(for: model)
                loadedAssetKey = assetKey
                isReady = false
                lastAnimationKind = ""
                lastScale = 0
                lastScaleAffectsCamera = nil
                lastFacingLeft = nil
                webView.loadFileURL(document.htmlURL, allowingReadAccessTo: document.readAccessURL)
            } catch {
                loadedAssetKey = assetKey
                isReady = false
                let message = "Spine renderer failed: \(error.localizedDescription)"
                webView.loadHTMLString("<html><body style='background:transparent;color:white'>\(message)</body></html>", baseURL: nil)
                NSLog("%@", message)
            }
        }

        func syncScale(_ model: PetModel) {
            guard isReady, let webView else { return }
            let scale = max(PetWindowMetrics.minimumRenderScale, min(model.renderScale, PetWindowMetrics.maximumRenderScale))
            let scaleAffectsCamera = !model.renderScaleControlsWindow
            guard abs(scale - lastScale) > 0.01 || scaleAffectsCamera != lastScaleAffectsCamera else { return }
            lastScale = scale
            lastScaleAffectsCamera = scaleAffectsCamera
            webView.evaluateJavaScript("window.setPetScale && window.setPetScale(\(Double(scale)), \(scaleAffectsCamera ? "true" : "false"))", completionHandler: nil)
        }

        func syncFacing(_ model: PetModel) {
            guard isReady, let webView else { return }
            guard model.facingLeft != lastFacingLeft else { return }
            lastFacingLeft = model.facingLeft
            webView.evaluateJavaScript("window.setPetFacingLeft && window.setPetFacingLeft(\(model.facingLeft ? "true" : "false"))", completionHandler: nil)
        }

        func syncAnimation(_ model: PetModel) {
            guard isReady, let webView else { return }
            let kind = model.animationKind()

            guard kind != lastAnimationKind else { return }
            lastAnimationKind = kind
            webView.evaluateJavaScript("window.setPetAnimation && window.setPetAnimation('\(kind)')", completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isReady = true
            if let currentModel {
                syncScale(currentModel)
                syncFacing(currentModel)
                syncAnimation(currentModel)
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }

            if type == "ready" {
                isReady = true
                if let currentModel {
                    syncScale(currentModel)
                    syncFacing(currentModel)
                    syncAnimation(currentModel)
                }
            } else if type == "bounds" {
                guard let aspect = body["aspect"] as? Double, aspect.isFinite, aspect > 0 else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let model = self?.currentModel else { return }
                    model.visualAspectRatio = CGFloat(aspect)
                }
            } else if type == "pixelBounds" {
                guard let kind = body["kind"] as? String else { return }
                guard let left = body["left"] as? Double,
                      let top = body["top"] as? Double,
                      let width = body["width"] as? Double,
                      let height = body["height"] as? Double,
                      left.isFinite, top.isFinite, width.isFinite, height.isFinite,
                      width > 16, height > 16 else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let model = self?.currentModel else { return }
                    guard kind == model.animationKind() else { return }
                    model.visualCropKind = kind
                    model.visualCropRect = CGRect(x: left, y: top, width: width, height: height)
                }
            } else if type == "animationComplete" {
                guard let kind = body["kind"] as? String else { return }
                DispatchQueue.main.async { [weak self] in
                    self?.currentModel?.finishOneShotAction(kind: kind)
                }
            } else if type == "error" {
                NSLog("Spine renderer error: %@", body["message"] as? String ?? "unknown")
            }
        }
    }
}
