import Foundation

struct ArkModelItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let type: String
    let skinName: String
    let tags: [String]
    let tagLabels: [String]
    let relativeDirectory: String
    let imageName: String
    let imageURL: URL?
    let atlasURL: URL?
    let skeletonURL: URL?
    let snapshotURL: URL?

    var isInstalled: Bool {
        imageURL != nil
    }

    var hasSpineAssets: Bool {
        atlasURL != nil && skeletonURL != nil
    }

    var searchableText: String {
        ([id, title, subtitle, type, skinName] + tags + tagLabels).joined(separator: " ").lowercased()
    }
}

struct ArkModelDataset: Decodable {
    let storageDirectory: [String: String]
    let sortTags: [String: String]?
    let data: [String: ArkModelEntry]
}

struct ArkModelEntry: Decodable {
    let assetId: String?
    let type: String
    let style: String?
    let name: String
    let appellation: String?
    let skinGroupName: String?
    let sortTags: [String]?
    let assetList: [String: AssetListValue]
}

enum AssetListValue: Decodable {
    case one(String)
    case many([String])

    var first: String? {
        switch self {
        case .one(let value):
            return value
        case .many(let values):
            return values.first
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .one(value)
        } else {
            self = .many(try container.decode([String].self))
        }
    }
}
