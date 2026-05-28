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
    private var lastPokeAt = Date.distantPast

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
        if kind == "interact", mood == .happy {
            mood = .idle
        } else if kind == "special", mood == .special {
            mood = .idle
        } else {
            return
        }
        velocity = CGVector(dx: 0, dy: 0)
        nextMoodChange = Date().addingTimeInterval(TimeInterval.random(in: 8...14))
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
        guard hasSpineAssets, visualCropKind == animationKind() else { return 0 }

        switch animationKind() {
        case "rest":
            return min(max(size.height * 0.30, 24), 76)
        case "sleep":
            if size.width > size.height * 1.2 {
                return min(max(size.height * 0.04, 0), 12)
            }
            return min(max(size.height * 0.28, 22), 70)
        default:
            return 0
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
        visualCropRect = nil
        visualCropKind = nil
        resetMotion()
    }
}
