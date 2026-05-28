import Foundation

struct SpineRendererDocument {
    let htmlURL: URL
    let readAccessURL: URL

    static func make(for model: PetModel) throws -> SpineRendererDocument {
        guard let atlasURL = model.atlasURL,
              let skeletonURL = model.skeletonURL,
              let imageURL = model.imageURL else {
            throw CocoaError(.fileNoSuchFile)
        }

        let directory = try rendererDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try installRuntimeScript(into: directory)

        let atlasText = try String(contentsOf: atlasURL, encoding: .utf8)
        let skeletonData = try Data(contentsOf: skeletonURL)
        let imageSources = try imageDataURIs(atlasText: atlasText, atlasURL: atlasURL, fallbackImageURL: imageURL)
        let html = htmlDocument(
            title: model.displayName,
            atlasText: atlasText,
            skeletonBase64: skeletonData.base64EncodedString(),
            imageSources: imageSources
        )

        let htmlURL = directory.appendingPathComponent("pet-renderer-\(rendererFileStem(for: skeletonURL)).html")
        try html.write(to: htmlURL, atomically: true, encoding: .utf8)
        return SpineRendererDocument(htmlURL: htmlURL, readAccessURL: directory)
    }

    private static func rendererDirectory() throws -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("MacArkPet/Renderer", isDirectory: true)
    }

    private static func installRuntimeScript(into directory: URL) throws {
        let destination = directory.appendingPathComponent("spine-webgl.js")
        let source = try runtimeScriptURL()
        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
    }

    private static func rendererFileStem(for skeletonURL: URL) -> String {
        let rawName = [
            skeletonURL.deletingLastPathComponent().lastPathComponent,
            skeletonURL.deletingPathExtension().lastPathComponent
        ].joined(separator: "-")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let scalars = rawName.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let result = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-_."))
        return result.isEmpty ? UUID().uuidString : result
    }

    private static func runtimeScriptURL() throws -> URL {
        let sourceFile = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("spine-webgl.js"),
            projectRoot.appendingPathComponent("Resources/spine-webgl.js"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/spine-webgl.js")
        ].compactMap { $0 }

        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }

        throw CocoaError(.fileNoSuchFile)
    }

    private static func imageDataURIs(atlasText: String, atlasURL: URL, fallbackImageURL: URL) throws -> [String: String] {
        var result: [String: String] = [:]
        let pageNames = atlasPageNames(in: atlasText)
        let baseDirectory = atlasURL.deletingLastPathComponent()

        for pageName in pageNames {
            let pageURL = baseDirectory.appendingPathComponent(pageName)
            let resolvedURL = FileManager.default.fileExists(atPath: pageURL.path) ? pageURL : fallbackImageURL
            let dataURI = try dataURI(for: resolvedURL)
            result[pageName] = dataURI
            result[URL(fileURLWithPath: pageName).lastPathComponent] = dataURI
        }

        if result.isEmpty {
            result[fallbackImageURL.lastPathComponent] = try dataURI(for: fallbackImageURL)
        }

        return result
    }

    private static func atlasPageNames(in atlasText: String) -> [String] {
        atlasText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                guard !line.isEmpty, !line.contains(":") else { return false }
                let lowercased = line.lowercased()
                return lowercased.hasSuffix(".png") || lowercased.hasSuffix(".jpg") || lowercased.hasSuffix(".jpeg") || lowercased.hasSuffix(".webp")
            }
    }

    private static func dataURI(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let mimeType: String
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg":
            mimeType = "image/jpeg"
        case "webp":
            mimeType = "image/webp"
        default:
            mimeType = "image/png"
        }
        return "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    private static func htmlDocument(title: String, atlasText: String, skeletonBase64: String, imageSources: [String: String]) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(escapedHTML(title))</title>
          <script src="./spine-webgl.js"></script>
          <style>
            html, body, canvas {
              margin: 0;
              width: 100%;
              height: 100%;
              overflow: hidden;
              background: transparent;
            }
            body { pointer-events: none; }
            canvas {
              position: absolute;
              inset: 0;
              display: block;
            }
          </style>
        </head>
        <body>
          <canvas id="canvas"></canvas>
          <script>
            const atlasText = \(jsString(atlasText));
            const skeletonBase64 = \(jsString(skeletonBase64));
            const imageSources = \(jsonObject(imageSources));

            let canvas;
            let context;
            let gl;
            let shader;
            let batcher;
            let mvp;
            let skeletonRenderer;
            let skeleton;
            let animationState;
            let fitBounds = { minX: -1, minY: -1, maxX: 1, maxY: 1 };
            let rootSetup = { x: 0, y: 0 };
            var facingLeft = false;
            var lastFrameTime = Date.now() / 1000;
            let animationNames = [];
            var currentAnimation = "";
            var currentKind = "";
            var oneShotCompletionSent = false;
            var userScale = 1;
            var scaleAffectsCamera = true;
            var framesSinceBoundsPost = 0;
            var pixelBoundsWarmupFrames = 0;
            var pixelBoundsSamples = 0;
            var accumulatedPixelBounds = null;
            var lastPixelBoundsKey = "";

            function post(message) {
              try {
                window.webkit.messageHandlers.pet.postMessage(message);
              } catch (_) {}
            }

            function decodeBase64(base64) {
              const binary = atob(base64);
              const bytes = new Uint8Array(binary.length);
              for (let index = 0; index < binary.length; index += 1) {
                bytes[index] = binary.charCodeAt(index);
              }
              return bytes;
            }

            function loadImage(source) {
              return new Promise((resolve, reject) => {
                const image = new Image();
                image.onload = () => resolve(image);
                image.onerror = () => reject(new Error("image load failed"));
                image.src = source;
              });
            }

            function finiteBounds(offset, size) {
              return Number.isFinite(offset.x) && Number.isFinite(offset.y)
                && Number.isFinite(size.x) && Number.isFinite(size.y)
                && size.x > 0 && size.y > 0;
            }

            function poseBounds(targetSkeleton) {
              const offset = new spine.Vector2();
              const size = new spine.Vector2();
              targetSkeleton.getBounds(offset, size, []);
              if (!finiteBounds(offset, size)) return null;
              return {
                minX: offset.x,
                minY: offset.y,
                maxX: offset.x + size.x,
                maxY: offset.y + size.y
              };
            }

            function unionBounds(first, second) {
              if (!second) return first;
              if (!first) return second;
              return {
                minX: Math.min(first.minX, second.minX),
                minY: Math.min(first.minY, second.minY),
                maxX: Math.max(first.maxX, second.maxX),
                maxY: Math.max(first.maxY, second.maxY)
              };
            }

            function unionPixelBounds(first, second) {
              if (!second) return first;
              if (!first) return second;
              const left = Math.min(first.left, second.left);
              const top = Math.min(first.top, second.top);
              const right = Math.max(first.left + first.width, second.left + second.width);
              const bottom = Math.max(first.top + first.height, second.top + second.height);
              return { left, top, width: right - left, height: bottom - top };
            }

            function snapPixelBounds(source) {
              const left = Math.floor(source.left);
              const top = Math.floor(source.top);
              const right = Math.ceil(source.left + source.width);
              const bottom = Math.ceil(source.top + source.height);
              return {
                left,
                top,
                width: Math.max(1, right - left),
                height: Math.max(1, bottom - top)
              };
            }

            function resetPixelBoundsTracking(warmupFrames = 0) {
              framesSinceBoundsPost = 0;
              pixelBoundsWarmupFrames = warmupFrames;
              pixelBoundsSamples = 0;
              accumulatedPixelBounds = null;
              lastPixelBoundsKey = "";
            }

            function padBounds(source) {
              const width = Math.max(1, source.maxX - source.minX);
              const height = Math.max(1, source.maxY - source.minY);
              const padX = Math.max(width * 0.06, 8);
              const padY = Math.max(height * 0.045, 8);
              return {
                minX: source.minX - padX,
                minY: source.minY - padY,
                maxX: source.maxX + padX,
                maxY: source.maxY + padY
              };
            }

            function lockRootMotion(targetSkeleton) {
              if (!targetSkeleton || !targetSkeleton.bones || targetSkeleton.bones.length === 0) return;
              const root = targetSkeleton.bones[0];
              root.x = rootSetup.x;
              root.y = rootSetup.y;
            }

            function includeMirroredPoseBounds(result, targetSkeleton) {
              const originalScaleX = targetSkeleton.scaleX || 1;
              const originalScaleY = targetSkeleton.scaleY || 1;
              for (const scaleX of [1, -1]) {
                targetSkeleton.scaleX = scaleX;
                targetSkeleton.scaleY = originalScaleY;
                targetSkeleton.updateWorldTransform();
                result = unionBounds(result, poseBounds(targetSkeleton));
              }
              targetSkeleton.scaleX = originalScaleX;
              targetSkeleton.scaleY = originalScaleY;
              targetSkeleton.updateWorldTransform();
              return result;
            }

            function calculateStableBounds(skeletonData) {
              const sample = new spine.Skeleton(skeletonData);
              const preferred = ["default", "idle", "relax", "sit", "sleep", "move", "walk", "run", "interact", "special"];
              let result = null;

              sample.setToSetupPose();
              lockRootMotion(sample);
              result = includeMirroredPoseBounds(result, sample);

              for (const animation of skeletonData.animations) {
                const lowerName = animation.name.toLowerCase();
                if (skeletonData.animations.length > 12 && !preferred.some((token) => lowerName.includes(token))) {
                  continue;
                }

                const steps = Math.max(2, Math.min(14, Math.ceil(animation.duration * 10)));
                for (let index = 0; index <= steps; index += 1) {
                  const time = animation.duration * (index / steps);
                  sample.setToSetupPose();
                  animation.apply(sample, 0, time, false, null, 1, spine.MixBlend.setup, spine.MixDirection.mixIn);
                  lockRootMotion(sample);
                  result = includeMirroredPoseBounds(result, sample);
                }
              }

              return padBounds(result || { minX: -1, minY: -1, maxX: 1, maxY: 1 });
            }

            function chooseAnimation(kind) {
              if (animationNames.length === 0) return null;
              const lower = animationNames.map((name) => name.toLowerCase());
              const groups = {
                sleep: ["sleep", "sit", "relax", "idle", "default"],
                rest: ["sit", "relax", "idle", "default"],
                special: ["special", "interact", "relax", "idle", "default"],
                interact: ["interact", "special", "relax", "idle", "default"],
                move: ["move", "walk", "run", "default", "relax", "idle"],
                idle: ["relax", "idle", "default", "move"]
              };
              for (const wanted of (groups[kind] || groups.idle)) {
                const exact = lower.indexOf(wanted);
                if (exact >= 0) return animationNames[exact];
                const partial = lower.findIndex((name) => name.includes(wanted));
                if (partial >= 0) return animationNames[partial];
              }
              return animationNames[0];
            }

            window.setPetAnimation = function(kind) {
              if (!animationState) return;
              const nextKind = kind || "idle";
              const next = chooseAnimation(nextKind);
              const isOneShot = nextKind === "interact" || nextKind === "special";
              if (!next || (next === currentAnimation && nextKind === currentKind && !isOneShot)) return;
              currentKind = nextKind;
              currentAnimation = next;
              oneShotCompletionSent = false;
              resetPixelBoundsTracking(18);
              animationState.setAnimation(0, next, !isOneShot);
            };

            window.setPetScale = function(scale, affectsCamera) {
              const nextScale = Number(scale);
              if (Number.isFinite(nextScale)) {
                userScale = Math.max(0.1, Math.min(nextScale, 6.0));
              }
              scaleAffectsCamera = affectsCamera !== false;
              resetPixelBoundsTracking(4);
            };

            window.setPetFacingLeft = function(nextFacingLeft) {
              facingLeft = !!nextFacingLeft;
            };

            async function init() {
              canvas = document.getElementById("canvas");
              context = new spine.webgl.ManagedWebGLRenderingContext(canvas, {
                alpha: true,
                antialias: true,
                premultipliedAlpha: false
              });
              gl = context.gl;
              gl.clearColor(0, 0, 0, 0);

              const loadedImages = {};
              const imageKeys = Object.keys(imageSources);
              for (const key of imageKeys) {
                loadedImages[key] = await loadImage(imageSources[key]);
              }

              const firstImage = loadedImages[imageKeys[0]];
              const atlas = new spine.TextureAtlas(atlasText, (path) => {
                const fileName = path.split("/").pop();
                const image = loadedImages[path] || loadedImages[fileName] || firstImage;
                return new spine.webgl.GLTexture(context, image);
              });

              const atlasLoader = new spine.AtlasAttachmentLoader(atlas);
              const skeletonBinary = new spine.SkeletonBinary(atlasLoader);
              skeletonBinary.scale = 1;
              const skeletonData = skeletonBinary.readSkeletonData(decodeBase64(skeletonBase64));
              for (const animation of skeletonData.animations) {
                animationNames.push(animation.name);
              }

              skeleton = new spine.Skeleton(skeletonData);
              if (skeleton.bones && skeleton.bones.length > 0) {
                rootSetup.x = skeleton.bones[0].x;
                rootSetup.y = skeleton.bones[0].y;
              }
              fitBounds.minX = -1;
              fitBounds.minY = -1;
              fitBounds.maxX = 1;
              fitBounds.maxY = 1;
              const calculatedBounds = calculateStableBounds(skeletonData);
              fitBounds.minX = calculatedBounds.minX;
              fitBounds.minY = calculatedBounds.minY;
              fitBounds.maxX = calculatedBounds.maxX;
              fitBounds.maxY = calculatedBounds.maxY;
              post({
                type: "bounds",
                width: Math.max(1, calculatedBounds.maxX - calculatedBounds.minX),
                height: Math.max(1, calculatedBounds.maxY - calculatedBounds.minY),
                aspect: Math.max(0.1, Math.min(4, (calculatedBounds.maxX - calculatedBounds.minX) / Math.max(1, calculatedBounds.maxY - calculatedBounds.minY)))
              });

              const stateData = new spine.AnimationStateData(skeleton.data);
              stateData.defaultMix = 0.18;
              animationState = new spine.AnimationState(stateData);
              animationState.addListener({
                complete: function(entry) {
                  if ((currentKind === "interact" || currentKind === "special") && !oneShotCompletionSent) {
                    oneShotCompletionSent = true;
                    post({ type: "animationComplete", kind: currentKind, animation: entry && entry.animation ? entry.animation.name : "" });
                  }
                }
              });

              shader = spine.webgl.Shader.newTwoColoredTextured(context);
              batcher = new spine.webgl.PolygonBatcher(context);
              mvp = new spine.webgl.Matrix4();
              skeletonRenderer = new spine.webgl.SkeletonRenderer(context);
              skeletonRenderer.premultipliedAlpha = false;

              window.setPetAnimation("move");
              post({ type: "ready", animations: animationNames });
              requestAnimationFrame(render);
            }

            function resize() {
              const ratio = window.devicePixelRatio || 1;
              const width = Math.max(1, Math.floor(canvas.clientWidth * ratio));
              const height = Math.max(1, Math.floor(canvas.clientHeight * ratio));
              if (canvas.width !== width || canvas.height !== height) {
                canvas.width = width;
                canvas.height = height;
              }

              const widthInWorld = Math.max(1, fitBounds.maxX - fitBounds.minX);
              const heightInWorld = Math.max(1, fitBounds.maxY - fitBounds.minY);
              const centerX = (fitBounds.minX + fitBounds.maxX) / 2;
              let scale = Math.max(widthInWorld / (canvas.width * 0.96), heightInWorld / (canvas.height * 0.98));
              if (!Number.isFinite(scale) || scale <= 0) scale = 1;
              scale = Math.max(scale / (scaleAffectsCamera ? userScale : 1), 0.08);

              const worldWidth = canvas.width * scale;
              const worldHeight = canvas.height * scale;
              const bottom = fitBounds.minY - heightInWorld * 0.005;
              mvp.ortho2d(centerX - worldWidth / 2, bottom, worldWidth, worldHeight);
              gl.viewport(0, 0, canvas.width, canvas.height);
            }

            function render() {
              const now = Date.now() / 1000;
              const delta = Math.min(now - lastFrameTime, 1 / 20);
              lastFrameTime = now;

              animationState.update(delta);
              animationState.apply(skeleton);
              lockRootMotion(skeleton);
              skeleton.scaleX = facingLeft ? -1 : 1;
              skeleton.updateWorldTransform();
              resize();

              gl.clearColor(0, 0, 0, 0);
              gl.clear(gl.COLOR_BUFFER_BIT);
              shader.bind();
              shader.setUniformi(spine.webgl.Shader.SAMPLER, 0);
              shader.setUniform4x4f(spine.webgl.Shader.MVP_MATRIX, mvp.values);
              batcher.begin(shader);
              skeletonRenderer.draw(batcher, skeleton);
              batcher.end();
              shader.unbind();

              framesSinceBoundsPost += 1;
              if (framesSinceBoundsPost >= 2 || !lastPixelBoundsKey) {
                framesSinceBoundsPost = 0;
                postPixelBounds();
              }

              requestAnimationFrame(render);
            }

            function postPixelBounds() {
              const width = canvas.width;
              const height = canvas.height;
              if (!width || !height) return;
              if (pixelBoundsWarmupFrames > 0) {
                pixelBoundsWarmupFrames -= 1;
                return;
              }

              const pixels = new Uint8Array(width * height * 4);
              gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, pixels);

              let minX = width;
              let minY = height;
              let maxX = -1;
              let maxY = -1;

              for (let y = 0; y < height; y += 1) {
                const row = y * width * 4;
                for (let x = 0; x < width; x += 1) {
                  const alpha = pixels[row + x * 4 + 3];
                  if (alpha > 2) {
                    if (x < minX) minX = x;
                    if (x > maxX) maxX = x;
                    if (y < minY) minY = y;
                    if (y > maxY) maxY = y;
                  }
                }
              }

              if (maxX < minX || maxY < minY) return;

              const ratio = window.devicePixelRatio || 1;
              const sideMargin = Math.max(2, 2 * ratio);
              const topMargin = Math.max(2, 2 * ratio);
              const bottomMargin = 0;
              minX = Math.max(0, minX - sideMargin);
              minY = Math.max(0, minY - bottomMargin);
              maxX = Math.min(width - 1, maxX + sideMargin);
              maxY = Math.min(height - 1, maxY + topMargin);

              const currentBounds = {
                left: minX / ratio,
                top: (height - maxY - 1) / ratio,
                width: (maxX - minX + 1) / ratio,
                height: (maxY - minY + 1) / ratio
              };
              accumulatedPixelBounds = unionPixelBounds(accumulatedPixelBounds, currentBounds);
              pixelBoundsSamples += 1;
              if (pixelBoundsSamples < 14) return;

              const stableBounds = snapPixelBounds(accumulatedPixelBounds);
              const key = [
                stableBounds.left,
                stableBounds.top,
                stableBounds.width,
                stableBounds.height
              ].join(",");
              if (key === lastPixelBoundsKey) return;
              lastPixelBoundsKey = key;

              post({
                type: "pixelBounds",
                kind: currentKind,
                left: stableBounds.left,
                top: stableBounds.top,
                width: stableBounds.width,
                height: stableBounds.height
              });
            }

            init().catch((error) => {
              post({ type: "error", message: String(error && error.stack ? error.stack : error) });
            });
          </script>
        </body>
        </html>
        """
    }

    private static func jsString(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let array = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return String(array.dropFirst().dropLast())
    }

    private static func jsonObject(_ dictionary: [String: String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private static func escapedHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
