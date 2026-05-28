import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case zhHans
    case en

    static let userDefaultsKey = "appLanguage"

    var id: String { rawValue }

    var resolved: AppLanguage {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
            return preferred.hasPrefix("zh") ? .zhHans : .en
        case .zhHans, .en:
            return self
        }
    }

    static var preferred: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: userDefaultsKey) ?? "") ?? .system
    }

    static var current: AppLanguage {
        preferred.resolved
    }

    static func setPreferredRawValue(_ rawValue: String) {
        UserDefaults.standard.set(rawValue, forKey: userDefaultsKey)
        NotificationCenter.default.post(name: .appLanguageDidChange, object: nil)
    }

    func pickerTitle(current language: AppLanguage) -> String {
        switch self {
        case .system:
            return L10n.pick(language, zh: "跟随系统", en: "System")
        case .zhHans:
            return "中文"
        case .en:
            return "English"
        }
    }
}

extension Notification.Name {
    static let appLanguageDidChange = Notification.Name("MacArkPetAppLanguageDidChange")
}

enum ModelStoreStatus {
    case readingLocalModels
    case noModels
    case loaded(count: Int)
    case looseLoaded(count: Int)
    case downloadingLibrary
    case unpackingLibrary
    case syncCompleted(count: Int)
    case syncFailed(String)
    case launchedFull(String)
    case launchedPet(String)
}

enum L10n {
    static func pick(_ language: AppLanguage, zh: String, en: String) -> String {
        language.resolved == .zhHans ? zh : en
    }

    static func launcherTitle(language: AppLanguage = .current) -> String {
        pick(language, zh: "MacArkPet 启动器", en: "MacArkPet Launcher")
    }

    static func searchPlaceholder(_ language: AppLanguage) -> String {
        pick(language, zh: "搜索中文名、英文名、皮肤、编号", en: "Search name, skin, or ID")
    }

    static func modelTypePicker(_ language: AppLanguage) -> String {
        pick(language, zh: "模型类型", en: "Model Type")
    }

    static func tagPicker(_ language: AppLanguage) -> String {
        pick(language, zh: "标签", en: "Tag")
    }

    static func allTags(_ language: AppLanguage) -> String {
        pick(language, zh: "全部标签", en: "All Tags")
    }

    static func randomHelp(_ language: AppLanguage) -> String {
        pick(language, zh: "随机选一个", en: "Pick a random model")
    }

    static func modelCount(filtered: Int, total: Int, language: AppLanguage) -> String {
        pick(language, zh: "\(filtered) / \(total) 个模型", en: "\(filtered) / \(total) models")
    }

    static func clear(_ language: AppLanguage) -> String {
        pick(language, zh: "清除", en: "Clear")
    }

    static func syncButton(isSyncing: Bool, language: AppLanguage) -> String {
        if isSyncing {
            return pick(language, zh: "同步中", en: "Syncing")
        }
        return pick(language, zh: "同步模型库", en: "Sync Models")
    }

    static func noModelTitle(_ language: AppLanguage) -> String {
        pick(language, zh: "没有模型", en: "No Models")
    }

    static func noModelHint(_ language: AppLanguage) -> String {
        pick(language, zh: "换个筛选条件，或者同步模型库。", en: "Try another filter, or sync the model library.")
    }

    static func fieldType(_ language: AppLanguage) -> String {
        pick(language, zh: "类型", en: "Type")
    }

    static func fieldOutfit(_ language: AppLanguage) -> String {
        pick(language, zh: "服装", en: "Outfit")
    }

    static func fieldTags(_ language: AppLanguage) -> String {
        pick(language, zh: "标签", en: "Tags")
    }

    static func fieldResources(_ language: AppLanguage) -> String {
        pick(language, zh: "资源", en: "Resources")
    }

    static func defaultOutfit(_ language: AppLanguage) -> String {
        pick(language, zh: "默认", en: "Default")
    }

    static func defaultOutfitLong(_ language: AppLanguage) -> String {
        pick(language, zh: "默认服装", en: "Default Outfit")
    }

    static func none(_ language: AppLanguage) -> String {
        pick(language, zh: "无", en: "None")
    }

    static func spineRecognized(_ language: AppLanguage) -> String {
        pick(language, zh: "已识别", en: "Detected")
    }

    static func spineMissing(_ language: AppLanguage) -> String {
        pick(language, zh: "缺少资源", en: "Missing Assets")
    }

    static func size(_ language: AppLanguage) -> String {
        pick(language, zh: "尺寸", en: "Size")
    }

    static func speed(_ language: AppLanguage) -> String {
        pick(language, zh: "速度", en: "Speed")
    }

    static func resetRecommendedHelp(enabled: Bool, language: AppLanguage) -> String {
        if enabled {
            return pick(language, zh: "恢复推荐值", en: "Restore recommended value")
        }
        return pick(language, zh: "已经是推荐值", en: "Already recommended")
    }

    static func launchButton(hasSpineAssets: Bool, language: AppLanguage) -> String {
        if hasSpineAssets {
            return pick(language, zh: "启动完整角色", en: "Launch Full Character")
        }
        return pick(language, zh: "启动桌宠", en: "Launch Pet")
    }

    static func missingModelHint(_ language: AppLanguage) -> String {
        pick(language, zh: "这个模型还没下载，先同步模型库。", en: "This model is not downloaded yet. Sync the model library first.")
    }

    static func language(_ language: AppLanguage) -> String {
        pick(language, zh: "语言", en: "Language")
    }

    static func modelFilterTitle(_ filter: ModelFilter, language: AppLanguage) -> String {
        switch filter {
        case .all:
            return pick(language, zh: "全部", en: "All")
        case .installed:
            return pick(language, zh: "本地", en: "Local")
        case .operators:
            return pick(language, zh: "干员", en: "Operators")
        case .dynIllust:
            return pick(language, zh: "动态", en: "Dynamic")
        case .enemies:
            return pick(language, zh: "敌人", en: "Enemies")
        }
    }

    static func modelTypeTitle(_ type: String, language: AppLanguage) -> String {
        switch type {
        case "Operator", "models":
            return pick(language, zh: "干员", en: "Operator")
        case "DynIllust", "models_illust":
            return pick(language, zh: "动态", en: "Dynamic")
        case "Enemy", "models_enemies":
            return pick(language, zh: "敌人", en: "Enemy")
        default:
            return type
        }
    }

    static func status(_ status: ModelStoreStatus, language: AppLanguage) -> String {
        switch status {
        case .readingLocalModels:
            return pick(language, zh: "正在读取本地模型", en: "Reading local models")
        case .noModels:
            return pick(language, zh: "没有找到模型，点同步模型库", en: "No models found. Sync the model library.")
        case .loaded(let count):
            return pick(language, zh: "已读取 \(count) 个模型", en: "Loaded \(count) models")
        case .looseLoaded(let count):
            return pick(language, zh: "已用本地目录扫描到 \(count) 个模型", en: "Scanned \(count) models from local folders")
        case .downloadingLibrary:
            return pick(language, zh: "正在下载模型库索引和资源包", en: "Downloading model index and assets")
        case .unpackingLibrary:
            return pick(language, zh: "正在解压模型库", en: "Unpacking model library")
        case .syncCompleted(let count):
            return pick(language, zh: "同步完成，已读取 \(count) 个模型", en: "Sync complete. Loaded \(count) models")
        case .syncFailed(let message):
            return pick(language, zh: "同步失败：\(message)", en: "Sync failed: \(message)")
        case .launchedFull(let title):
            return pick(language, zh: "已在 MacArkPet 内启动完整角色：\(title)", en: "Launched full character in MacArkPet: \(title)")
        case .launchedPet(let title):
            return pick(language, zh: "已启动桌宠：\(title)", en: "Launched desktop pet: \(title)")
        }
    }

    static func menuOpenLauncher(_ language: AppLanguage) -> String {
        pick(language, zh: "打开启动器", en: "Open Launcher")
    }

    static func menuPoke(_ language: AppLanguage) -> String {
        pick(language, zh: "开心一下", en: "Cheer Up")
    }

    static func menuSpecialAction(_ language: AppLanguage) -> String {
        pick(language, zh: "特殊动作", en: "Special Action")
    }

    static func menuRest(_ language: AppLanguage) -> String {
        pick(language, zh: "坐下休息", en: "Sit and Rest")
    }

    static func menuSleep(_ language: AppLanguage) -> String {
        pick(language, zh: "睡一会儿", en: "Sleep")
    }

    static func menuClickThrough(_ language: AppLanguage) -> String {
        pick(language, zh: "点击穿透", en: "Click Through")
    }

    static func menuAlwaysOnTop(_ language: AppLanguage) -> String {
        pick(language, zh: "保持置顶", en: "Always on Top")
    }

    static func menuResetPosition(_ language: AppLanguage) -> String {
        pick(language, zh: "回到屏幕中间", en: "Reset Position")
    }

    static func menuQuit(_ language: AppLanguage) -> String {
        pick(language, zh: "退出", en: "Quit")
    }
}
