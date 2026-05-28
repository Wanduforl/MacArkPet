// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 MacArkPet contributors

import SwiftUI

struct LauncherView: View {
    @ObservedObject var store: ArkModelStore
    let onLaunch: (ArkModelItem) -> Void
    let onScaleChange: (ArkModelItem, Double) -> Void
    @AppStorage(AppLanguage.userDefaultsKey) private var languageRaw = AppLanguage.system.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRaw) ?? .system
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
    }

    private var sidebar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(L10n.searchPlaceholder(language), text: $store.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Picker(L10n.modelTypePicker(language), selection: $store.modelFilter) {
                ForEach(ModelFilter.allCases) { filter in
                    Text(filter.title(language: language)).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)

            HStack(spacing: 8) {
                Picker(L10n.tagPicker(language), selection: $store.tagFilter) {
                    Text(L10n.allTags(language)).tag("")
                    ForEach(store.availableTagFilters, id: \.id) { tag in
                        Text(tag.label).tag(tag.id)
                    }
                }
                .labelsHidden()

                Button {
                    store.selectRandomModel()
                } label: {
                    Image(systemName: "shuffle")
                }
                .help(L10n.randomHelp(language))
            }
            .padding(.horizontal, 12)

            HStack {
                Text(L10n.modelCount(filtered: store.filteredModels.count, total: store.models.count, language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !store.searchText.isEmpty || !store.tagFilter.isEmpty || store.modelFilter != .installed {
                    Button(L10n.clear(language)) {
                        store.searchText = ""
                        store.tagFilter = ""
                        store.modelFilter = .installed
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }
            }
            .padding(.horizontal, 12)

            List(selection: $store.selectedModelID) {
                ForEach(store.filteredModels) { model in
                    ModelRow(model: model, language: language)
                        .tag(model.id)
                }
            }
            .listStyle(.sidebar)
        }
        .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 420)
    }

    private var detail: some View {
        VStack(spacing: 0) {
            if let model = store.selectedModel {
                ModelDetail(
                    model: model,
                    isSyncing: store.isSyncing,
                    language: language,
                    petScale: Binding(
                        get: { store.scale(for: model) },
                        set: { newScale in
                            store.setScale(newScale, for: model)
                            onScaleChange(model, newScale)
                        }
                    ),
                    hasScaleOverride: store.hasScaleOverride(for: model),
                    petSpeed: $store.petSpeed,
                    resetScale: {
                        store.resetScale(for: model)
                        onScaleChange(model, store.scale(for: model))
                    }
                ) {
                    onLaunch(model)
                }
            } else {
                EmptyModelView(language: language)
            }

            Divider()

            HStack {
                if store.isSyncing || store.syncProgress != nil {
                    SyncProgressRing(
                        progress: store.syncProgress ?? 0,
                        statusText: store.statusText(language: language),
                        detailText: store.syncDetailText(language: language),
                        language: language
                    )
                } else {
                    Text(store.statusText(language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                LanguagePicker(language: language, languageRaw: $languageRaw)

                Button {
                    Task { await store.syncModelLibrary() }
                } label: {
                    Label(L10n.syncButton(isSyncing: store.isSyncing, language: language), systemImage: "arrow.down.circle")
                }
                .disabled(store.isSyncing)
            }
            .padding(12)
        }
    }
}

private struct SyncProgressRing: View {
    let progress: Double
    let statusText: String
    let detailText: String
    let language: AppLanguage

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 4)
                Circle()
                    .trim(from: 0, to: clampedProgress)
                    .stroke(.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.18), value: clampedProgress)
                Text(L10n.progressPercent(clampedProgress, language: language))
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text(detailText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: 260, alignment: .leading)
        }
        .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
        .help("\(statusText)\n\(detailText)")
    }
}

private struct EmptyModelView: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text(L10n.noModelTitle(language))
                .font(.title2.weight(.semibold))
            Text(L10n.noModelHint(language))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ModelRow: View {
    let model: ArkModelItem
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 10) {
            ModelThumb(model: model)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.title)
                    .lineLimit(1)
                Text(model.subtitleLine(language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(model.typeTitle(language: language))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if model.isInstalled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ModelDetail: View {
    let model: ArkModelItem
    let isSyncing: Bool
    let language: AppLanguage
    @Binding var petScale: Double
    let hasScaleOverride: Bool
    @Binding var petSpeed: Double
    let resetScale: () -> Void
    let onLaunch: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                if model.hasSpineAssets {
                    SpineModelPreview(model: model, scale: petScale)
                        .id(model.id)
                        .padding(8)
                } else if let image = model.preview {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(20)
                } else {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 52))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 320, height: 380)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.title)
                        .font(.largeTitle.weight(.semibold))
                        .lineLimit(2)
                    Text(model.subtitle)
                        .foregroundStyle(.secondary)
                }

                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                    GridRow {
                        Text(L10n.fieldType(language)).foregroundStyle(.secondary)
                        Text(model.typeTitle(language: language))
                    }
                    GridRow {
                        Text(L10n.fieldOutfit(language)).foregroundStyle(.secondary)
                        Text(model.skinName.isEmpty ? L10n.defaultOutfit(language) : model.skinName)
                    }
                    GridRow {
                        Text(L10n.fieldTags(language)).foregroundStyle(.secondary)
                        Text(model.tagLine(language: language))
                            .lineLimit(2)
                    }
                    GridRow {
                        Text(L10n.fieldResources(language)).foregroundStyle(.secondary)
                        Text(model.relativeDirectory)
                            .lineLimit(2)
                    }
                    GridRow {
                        Text("Spine").foregroundStyle(.secondary)
                        Text(model.hasSpineAssets ? L10n.spineRecognized(language) : L10n.spineMissing(language))
                    }
                }
                .font(.callout)

                VStack(spacing: 12) {
                    TuningControl(
                        title: L10n.size(language),
                        systemImage: "arrow.up.left.and.arrow.down.right",
                        value: $petScale,
                        range: Double(PetWindowMetrics.minimumRenderScale)...Double(PetWindowMetrics.maximumRenderScale),
                        step: 0.1,
                        displayValue: "\(Int(petScale * 100))%",
                        resetAction: resetScale,
                        resetEnabled: hasScaleOverride,
                        language: language
                    )

                    TuningControl(
                        title: L10n.speed(language),
                        systemImage: "speedometer",
                        value: $petSpeed,
                        range: 10...120,
                        step: 2,
                        displayValue: "\(Int(petSpeed))",
                        resetAction: nil,
                        resetEnabled: false,
                        language: language
                    )
                }

                Spacer()

                Button {
                    onLaunch()
                } label: {
                    Label(L10n.launchButton(hasSpineAssets: model.hasSpineAssets, language: language), systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!model.isInstalled || isSyncing)

                if !model.isInstalled {
                    Text(L10n.missingModelHint(language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 360, alignment: .leading)
        }
        .padding(24)
    }
}

private struct TuningControl: View {
    let title: String
    let systemImage: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let displayValue: String
    let resetAction: (() -> Void)?
    let resetEnabled: Bool
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.callout.weight(.medium))
                Spacer()
                Text(displayValue)
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .frame(minWidth: 54, alignment: .trailing)
            }

            HStack(spacing: 10) {
                Button {
                    value = max(range.lowerBound, value - step)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Slider(value: $value, in: range, step: step)
                    .controlSize(.large)

                Button {
                    value = min(range.upperBound, value + step)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                if let resetAction {
                    Button(action: resetAction) {
                        Image(systemName: "arrow.counterclockwise")
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .help(L10n.resetRecommendedHelp(enabled: resetEnabled, language: language))
                    .disabled(!resetEnabled)
                }
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct LanguagePicker: View {
    let language: AppLanguage
    @Binding var languageRaw: String

    var body: some View {
        Picker(L10n.language(language), selection: Binding(
            get: { languageRaw },
            set: { newValue in
                languageRaw = newValue
                AppLanguage.setPreferredRawValue(newValue)
            }
        )) {
            ForEach(AppLanguage.allCases) { option in
                Text(option.pickerTitle(current: language)).tag(option.rawValue)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(width: 116)
        .help(L10n.language(language))
    }
}

private struct ModelThumb: View {
    let model: ArkModelItem

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)

            if let image = model.thumbnail {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(3)
            } else {
                Image(systemName: model.hasSpineAssets ? "figure.stand" : "cube")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SpineModelPreview: View {
    let model: ArkModelItem
    let scale: Double
    @StateObject private var petModel = PetModel()

    var body: some View {
        SpinePetWebView(model: petModel)
            .id(model.id)
            .allowsHitTesting(false)
            .onAppear(perform: configure)
            .onChange(of: model.id) { _ in configure() }
            .onChange(of: scale) { newValue in
                petModel.renderScale = CGFloat(newValue)
            }
    }

    private func configure() {
        petModel.apply(model: model)
        petModel.velocity.dx = 0
        petModel.renderScale = CGFloat(scale)
    }
}

private extension ArkModelItem {
    func typeTitle(language: AppLanguage) -> String {
        L10n.modelTypeTitle(type, language: language)
    }

    func subtitleLine(language: AppLanguage) -> String {
        let skin = skinName.isEmpty ? L10n.defaultOutfitLong(language) : skinName
        if subtitle.isEmpty || subtitle == id {
            return skin
        }
        return "\(subtitle) · \(skin)"
    }

    func tagLine(language: AppLanguage) -> String {
        tagLabels.isEmpty ? L10n.none(language) : tagLabels.joined(separator: language.resolved == .zhHans ? "、" : ", ")
    }

    var thumbnail: NSImage? {
        guard let url = snapshotURL ?? (!hasSpineAssets ? imageURL : nil) else { return nil }
        let image = NSImage(contentsOf: url)
        image?.size = NSSize(width: 84, height: 84)
        return image
    }

    var preview: NSImage? {
        guard let url = snapshotURL ?? (!hasSpineAssets ? imageURL : nil) else { return nil }
        return NSImage(contentsOf: url)
    }
}
