import AppKit
import Foundation

enum ModelFilter: String, CaseIterable, Identifiable {
    case all
    case installed
    case operators
    case dynIllust
    case enemies

    var id: String { rawValue }

    func title(language: AppLanguage = .current) -> String {
        L10n.modelFilterTitle(self, language: language)
    }

    func contains(_ model: ArkModelItem) -> Bool {
        switch self {
        case .all:
            return true
        case .installed:
            return model.isInstalled
        case .operators:
            return model.type == "Operator" || model.tags.contains("Operator")
        case .dynIllust:
            return model.type == "DynIllust" || model.tags.contains("DynIllust")
        case .enemies:
            return model.type == "Enemy" || model.tags.contains { $0.hasPrefix("Enemy") }
        }
    }
}

final class ArkModelStore: ObservableObject {
    @Published private(set) var models: [ArkModelItem] = []
    @Published var searchText = ""
    @Published var modelFilter: ModelFilter = .installed
    @Published var tagFilter = ""
    @Published var selectedModelID: ArkModelItem.ID?
    @Published var status: ModelStoreStatus = .readingLocalModels
    @Published var isSyncing = false
    @Published private var scaleOverrides: [String: Double] = ArkModelStore.loadScaleOverrides()
    @Published var petSpeed: Double = UserDefaults.standard.object(forKey: "petSpeed") as? Double ?? 42 {
        didSet { UserDefaults.standard.set(petSpeed, forKey: "petSpeed") }
    }

    private let fileManager = FileManager.default
    private let remoteDatasetURL = URL(string: "https://raw.githubusercontent.com/isHarryh/Ark-Models/main/models_data.json")!
    private let archiveURL = URL(string: "https://github.com/isHarryh/Ark-Models/archive/refs/heads/main.zip")!

    private var appSupportRoot: URL {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent("MacArkPet/ArkModels", isDirectory: true)
    }

    private var assetRoots: [URL] {
        ([appSupportRoot] + developmentAssetRoots).filter { fileManager.fileExists(atPath: $0.path) }
    }

    private var developmentAssetRoots: [URL] {
        var roots: [URL] = []

        if let customAssetsPath = ProcessInfo.processInfo.environment["ARK_PETS_ASSETS"],
           !customAssetsPath.isEmpty {
            roots.append(URL(fileURLWithPath: customAssetsPath, isDirectory: true))
        }

        let sourceFile = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        roots.append(projectRoot.deletingLastPathComponent().appendingPathComponent("Ark-Pets/assets", isDirectory: true))
        return roots
    }

    var filteredModels: [ArkModelItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return models.filter { model in
            modelFilter.contains(model)
                && (tagFilter.isEmpty || model.tags.contains(tagFilter))
                && (query.isEmpty || model.searchableText.contains(query))
        }
    }

    var selectedModel: ArkModelItem? {
        guard let selectedModelID else { return filteredModels.first ?? models.first }
        return filteredModels.first { $0.id == selectedModelID } ?? filteredModels.first ?? models.first
    }

    func statusText(language: AppLanguage = .current) -> String {
        L10n.status(status, language: language)
    }

    var availableTagFilters: [(id: String, label: String)] {
        let pairs = models.flatMap { model in
            zip(model.tags, model.tagLabels).map { (id: $0.0, label: $0.1) }
        }
        var seen = Set<String>()
        return pairs
            .filter { pair in
                guard !seen.contains(pair.id) else { return false }
                seen.insert(pair.id)
                return true
            }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    func selectRandomModel() {
        guard let random = filteredModels.randomElement() ?? models.randomElement() else { return }
        selectedModelID = random.id
    }

    func scale(for model: ArkModelItem) -> Double {
        scaleOverrides[model.id] ?? recommendedScale(for: model)
    }

    func setScale(_ scale: Double, for model: ArkModelItem) {
        let clamped = min(max(scale, Double(PetWindowMetrics.minimumRenderScale)), Double(PetWindowMetrics.maximumRenderScale))
        scaleOverrides[model.id] = clamped
        saveScaleOverrides()
    }

    func resetScale(for model: ArkModelItem) {
        scaleOverrides.removeValue(forKey: model.id)
        saveScaleOverrides()
    }

    func hasScaleOverride(for model: ArkModelItem) -> Bool {
        scaleOverrides[model.id] != nil
    }

    func load() {
        do {
            models = try loadFromBestDataset()
            selectedModelID = selectedModelID ?? models.first(where: { $0.title.contains("缪尔赛思") })?.id ?? models.first?.id
            status = models.isEmpty ? .noModels : .loaded(count: models.count)
        } catch {
            models = scanLooseLocalModels()
            selectedModelID = models.first?.id
            status = models.isEmpty ? .noModels : .looseLoaded(count: models.count)
        }
    }

    func syncModelLibrary() async {
        guard !isSyncing else { return }
        isSyncing = true
        status = .downloadingLibrary

        do {
            try fileManager.createDirectory(at: appSupportRoot, withIntermediateDirectories: true)
            let archiveFile = appSupportRoot.appendingPathComponent("Ark-Models-main.zip")
            let (temporaryFile, _) = try await URLSession.shared.download(from: archiveURL)
            if fileManager.fileExists(atPath: archiveFile.path) {
                try fileManager.removeItem(at: archiveFile)
            }
            try fileManager.moveItem(at: temporaryFile, to: archiveFile)

            status = .unpackingLibrary
            let unpackRoot = appSupportRoot.appendingPathComponent("_unpack", isDirectory: true)
            if fileManager.fileExists(atPath: unpackRoot.path) {
                try fileManager.removeItem(at: unpackRoot)
            }
            try fileManager.createDirectory(at: unpackRoot, withIntermediateDirectories: true)
            try unzip(archiveFile, to: unpackRoot)

            let sourceRoot = unpackRoot.appendingPathComponent("Ark-Models-main", isDirectory: true)
            try copyIfPresent("models_data.json", from: sourceRoot, to: appSupportRoot)
            try copyIfPresent("models", from: sourceRoot, to: appSupportRoot)
            try copyIfPresent("models_illust", from: sourceRoot, to: appSupportRoot)
            try copyIfPresent("models_enemies", from: sourceRoot, to: appSupportRoot)
            try? fileManager.removeItem(at: unpackRoot)

            load()
            status = .syncCompleted(count: models.count)
        } catch {
            status = .syncFailed(error.localizedDescription)
        }

        isSyncing = false
    }

    private func loadFromBestDataset() throws -> [ArkModelItem] {
        let datasetURL = try datasetCandidates().first {
            fileManager.fileExists(atPath: $0.path)
        }.unwrap()
        let data = try Data(contentsOf: datasetURL)
        let dataset = try JSONDecoder().decode(ArkModelDataset.self, from: data)

        return dataset.data.map { key, entry in
            let storageFolder = dataset.storageDirectory[entry.type] ?? "models"
            let assetId = entry.assetId ?? key
            let tags = entry.sortTags ?? []
            let tagLabels = tags.map { dataset.sortTags?[$0] ?? $0 }
            let imageName = entry.assetList[".png"]?.first ?? "\(assetId).png"
            let atlasName = entry.assetList[".atlas"]?.first
            let skeletonName = entry.assetList[".skel"]?.first ?? entry.assetList[".json"]?.first
            let relativeDirectory = "\(storageFolder)/\(key)"
            let imageURL = firstExistingImageURL(relativeDirectory: relativeDirectory, imageName: imageName)
            let atlasURL = firstExistingAssetURL(relativeDirectory: relativeDirectory, fileName: atlasName)
            let skeletonURL = firstExistingAssetURL(relativeDirectory: relativeDirectory, fileName: skeletonName)
            let snapshotURL = firstExistingSnapshotURL(assetBaseNames: [
                assetId,
                URL(fileURLWithPath: imageName).deletingPathExtension().lastPathComponent,
                skeletonName.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
            ].compactMap { $0 })
            return ArkModelItem(
                id: key,
                title: entry.name,
                subtitle: entry.appellation ?? key,
                type: entry.type,
                skinName: entry.skinGroupName ?? entry.style ?? "",
                tags: tags,
                tagLabels: tagLabels,
                relativeDirectory: relativeDirectory,
                imageName: imageName,
                imageURL: imageURL,
                atlasURL: atlasURL,
                skeletonURL: skeletonURL,
                snapshotURL: snapshotURL
            )
        }
        .filter { $0.isInstalled || $0.type == "Operator" || $0.type == "DynIllust" }
        .sorted {
            if $0.isInstalled != $1.isInstalled { return $0.isInstalled && !$1.isInstalled }
            if $0.title != $1.title { return $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            return $0.id.localizedStandardCompare($1.id) == .orderedAscending
        }
    }

    private func scanLooseLocalModels() -> [ArkModelItem] {
        var result: [ArkModelItem] = []
        for root in assetRoots {
            for folderName in ["models", "models_illust", "models_enemies"] {
                let folder = root.appendingPathComponent(folderName, isDirectory: true)
                guard let children = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
                    continue
                }
                for child in children where child.hasDirectoryPath {
                    guard let image = firstPNG(in: child) else { continue }
                    let atlas = firstFile(in: child, extensions: ["atlas"])
                    let skeleton = firstFile(in: child, extensions: ["skel", "json"])
                    let id = child.lastPathComponent
                    result.append(ArkModelItem(
                        id: "\(folderName)/\(id)",
                        title: readableTitle(from: id),
                        subtitle: id,
                        type: folderName,
                        skinName: "",
                        tags: [],
                        tagLabels: [],
                        relativeDirectory: "\(folderName)/\(id)",
                        imageName: image.lastPathComponent,
                        imageURL: image,
                        atlasURL: atlas,
                        skeletonURL: skeleton,
                        snapshotURL: firstExistingSnapshotURL(assetBaseNames: [
                            image.deletingPathExtension().lastPathComponent,
                            skeleton?.deletingPathExtension().lastPathComponent
                        ].compactMap { $0 })
                    ))
                }
            }
        }
        return result.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private func datasetCandidates() -> [URL] {
        var candidates = [appSupportRoot.appendingPathComponent("models_data.json")]
        candidates.append(contentsOf: developmentAssetRoots.map { $0.appendingPathComponent("models_data.json") })
        return candidates
    }

    private func firstExistingImageURL(relativeDirectory: String, imageName: String) -> URL? {
        for root in assetRoots {
            let directory = root.appendingPathComponent(relativeDirectory, isDirectory: true)
            let exact = directory.appendingPathComponent(imageName)
            if fileManager.fileExists(atPath: exact.path) {
                return exact
            }
            if let fallback = firstPNG(in: directory) {
                return fallback
            }
        }
        return nil
    }

    private func firstExistingSnapshotURL(assetBaseNames: [String]) -> URL? {
        let directories = [
            appSupportRoot.deletingLastPathComponent().appendingPathComponent("Preview", isDirectory: true),
            appSupportRoot.appendingPathComponent("temp", isDirectory: true),
        ] + developmentAssetRoots.map { $0.appendingPathComponent("temp", isDirectory: true) }

        for directory in directories where fileManager.fileExists(atPath: directory.path) {
            for baseName in assetBaseNames {
                let candidates = [
                    "acSnapshot-\(baseName)-0.png",
                    "\(baseName).png"
                ]
                for candidate in candidates {
                    let url = directory.appendingPathComponent(candidate)
                    if fileManager.fileExists(atPath: url.path) {
                        return url
                    }
                }
            }
        }
        return nil
    }

    private func firstExistingAssetURL(relativeDirectory: String, fileName: String?) -> URL? {
        guard let fileName else { return nil }
        for root in assetRoots {
            let exact = root.appendingPathComponent(relativeDirectory, isDirectory: true).appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: exact.path) {
                return exact
            }
        }
        return nil
    }

    private func firstPNG(in directory: URL) -> URL? {
        firstFile(in: directory, extensions: ["png"])
    }

    private func firstFile(in directory: URL, extensions allowedExtensions: Set<String>) -> URL? {
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return nil
        }
        return files
            .filter { allowedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .first
    }

    private func copyIfPresent(_ name: String, from sourceRoot: URL, to destinationRoot: URL) throws {
        let source = sourceRoot.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: source.path) else { return }
        let destination = destinationRoot.appendingPathComponent(name)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }

    private func unzip(_ archive: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", archive.path, "-d", destination.path]
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    private func readableTitle(from identifier: String) -> String {
        identifier
            .replacingOccurrences(of: "dyn_illust_", with: "")
            .replacingOccurrences(of: "build_char_", with: "")
            .replacingOccurrences(of: "_", with: " ")
    }

    private func recommendedScale(for model: ArkModelItem) -> Double {
        if model.type == "Enemy" || model.tags.contains(where: { $0.hasPrefix("Enemy") }) {
            return 0.82
        }
        if model.type == "DynIllust" || model.tags.contains("DynIllust") {
            return 0.78
        }
        return 1.08
    }

    private func saveScaleOverrides() {
        guard let data = try? JSONEncoder().encode(scaleOverrides) else { return }
        UserDefaults.standard.set(data, forKey: "modelScaleOverrides")
    }

    private static func loadScaleOverrides() -> [String: Double] {
        guard let data = UserDefaults.standard.data(forKey: "modelScaleOverrides"),
              let overrides = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return [:]
        }
        return overrides
    }
}

private extension Optional {
    func unwrap() throws -> Wrapped {
        guard let self else { throw CocoaError(.fileNoSuchFile) }
        return self
    }
}
