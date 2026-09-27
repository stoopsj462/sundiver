//
//  GameModel.swift
//  Sundiver
//

import SwiftUI
import Combine

enum GamePhase {
    case menu
    case playing
    case gameOver
}

/// Every knob that defines how a difficulty level plays.
struct DifficultyTuning {
    let baseAngularSpeed: Double        // dive speed at score 0, radians/second
    let maxSpeedBoost: Double           // ceiling the ramp adds on top of the base
    let speedRamp: Double               // speed gained per radian travelled
    let startSpawnGap: Double           // radians between spawn slots at the start
    let minSpawnGap: Double             // tightest the slots ever get
    let gapTighten: Double              // gap removed per radian travelled
    let flareChance: Double             // odds a slot rolls a flare instead of an ember
    let shieldChance: Double            // odds a slot rolls a shield
    let orbChance: Double               // odds a slot rolls a pulse orb
    let flareHalfWidth: ClosedRange<Double>  // arc half-width of a flare, radians
    let startDelay: Double              // held-still beat before the dive begins
    /// Seconds of completely clear track the player is guaranteed between a flare on
    /// one path and the next flare on the other — the window to make the dive.
    /// Bigger is more forgiving; this is the knob that decides how tight a level feels.
    let minSwitchWindow: Double
    /// Pulse orbs handed out at the start of a run.
    let startingOrbs: Int
    /// Speed scale applied while riding the inner ring.
    let innerLaneSpeed: Double
    /// Speed scale applied while riding the outer ring. When this differs from
    /// `innerLaneSpeed` the two paths run at different speeds and every dive
    /// between them changes the pace of the run.
    let outerLaneSpeed: Double

    /// True when the two paths do not run at the same speed.
    var hasAsymmetricLanes: Bool { innerLaneSpeed != outerLaneSpeed }
}

/// The four selectable levels of play. Each owns its full tuning curve and its own
/// persisted best score, so a gentle run on Easy never overwrites an Extreme record.
enum Difficulty: String, CaseIterable, Identifiable {
    case easy, normal, hard, extreme

    var id: String { rawValue }

    var name: String {
        switch self {
        case .easy:    return "EASY"
        case .normal:  return "NORMAL"
        case .hard:    return "HARD"
        case .extreme: return "EXTREME"
        }
    }

    /// Accent color for the picker pills and the in-run HUD badge.
    var tint: Color {
        switch self {
        case .easy:    return Color(red: 0.42, green: 1.00, blue: 0.55)
        case .normal:  return Color(red: 0.30, green: 0.85, blue: 1.00)
        case .hard:    return Color(red: 1.00, green: 0.55, blue: 0.20)
        case .extreme: return Color(red: 1.00, green: 0.26, blue: 0.40)
        }
    }

    /// Normal reproduces the original single-difficulty curve exactly.
    var tuning: DifficultyTuning {
        switch self {
        case .easy:
            return DifficultyTuning(baseAngularSpeed: 0.85, maxSpeedBoost: 1.10, speedRamp: 0.0035,
                                    startSpawnGap: 1.35, minSpawnGap: 0.85, gapTighten: 0.0015,
                                    flareChance: 0.32, shieldChance: 0.10, orbChance: 0.05,
                                    flareHalfWidth: 0.08...0.14, startDelay: 2.0,
                                    minSwitchWindow: 0.26, startingOrbs: 1,
                                    innerLaneSpeed: 1.0, outerLaneSpeed: 1.0)
        case .normal:
            return DifficultyTuning(baseAngularSpeed: 1.05, maxSpeedBoost: 1.55, speedRamp: 0.006,
                                    startSpawnGap: 1.15, minSpawnGap: 0.62, gapTighten: 0.0025,
                                    flareChance: 0.45, shieldChance: 0.06, orbChance: 0.045,
                                    flareHalfWidth: 0.10...0.19, startDelay: 1.5,
                                    minSwitchWindow: 0.18, startingOrbs: 1,
                                    innerLaneSpeed: 1.0, outerLaneSpeed: 1.0)
        case .hard:
            return DifficultyTuning(baseAngularSpeed: 1.25, maxSpeedBoost: 1.85, speedRamp: 0.0075,
                                    startSpawnGap: 1.05, minSpawnGap: 0.56, gapTighten: 0.0030,
                                    flareChance: 0.55, shieldChance: 0.04, orbChance: 0.04,
                                    flareHalfWidth: 0.12...0.22, startDelay: 1.3,
                                    minSwitchWindow: 0.14, startingOrbs: 2,
                                    innerLaneSpeed: 1.0, outerLaneSpeed: 1.0)
        case .extreme:
            // The two paths run at different speeds here: the outer ring is the fast,
            // high-risk lane and the inner ring is the slow one, so every dive between
            // them shifts the pace of the run.
            return DifficultyTuning(baseAngularSpeed: 1.35, maxSpeedBoost: 1.85, speedRamp: 0.0090,
                                    startSpawnGap: 0.95, minSpawnGap: 0.50, gapTighten: 0.0035,
                                    flareChance: 0.62, shieldChance: 0.03, orbChance: 0.04,
                                    flareHalfWidth: 0.13...0.25, startDelay: 1.1,
                                    minSwitchWindow: 0.11, startingOrbs: 2,
                                    innerLaneSpeed: 0.82, outerLaneSpeed: 1.30)
        }
    }
}

struct OrbitSkin: Identifiable, Equatable {
    let id: Int
    let name: String
    let color: Color
    let unlockScore: Int
}

struct TrailStyle: Identifiable, Equatable {
    let id: String
    let name: String
    let cost: Int
}

/// A recolor of the sun's body and glow.
struct SunTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let cost: Int
    let core: Color
    let mid: Color
    let edge: Color
    let glow: Color
    /// True only for "Prism Star" — GameView cycles its gradient through hue instead
    /// of using `core`/`mid`/`edge`/`glow`, which are unused placeholders for it.
    var isPrismatic: Bool = false
}

/// A recolor of the drifting background starfield.
struct StarfieldTheme: Identifiable, Equatable {
    enum Style: Equatable {
        /// Each star picks a fixed color from the palette, keyed by its own hueSeed.
        case palette([Color])
        /// Every star's hue cycles continuously over time, offset by its hueSeed.
        case chromatic
    }
    let id: String
    let name: String
    let cost: Int
    let style: Style
}

struct TrackItem: Identifiable {
    enum Kind { case flare, ember, shield, orb }
    let id = UUID()
    var kind: Kind
    var ring: Int
    var angle: Double
    var halfWidth: Double = 0
    var collected = false
}

/// The expanding ring left behind when a pulse orb detonates a flare.
struct Shockwave: Identifiable {
    let id = UUID()
    var pos: CGPoint
    var color: Color
    var age: Double = 0
    var duration: Double = 0.45
}

struct Particle: Identifiable {
    let id = UUID()
    var pos: CGPoint
    var vel: CGVector
    var color: Color
    var size: CGFloat
    var life: Double
    var maxLife: Double
}

struct BackgroundStar {
    var angle: Double
    var radius: Double
    var alpha: Double
    var size: CGFloat
    /// Fixed per star at creation. Themed palettes and the chromatic theme both key
    /// off this so a given star's color stays stable frame to frame.
    var hueSeed: Double = 0
}

@MainActor
final class GameModel: ObservableObject {

    static let skins: [OrbitSkin] = [
        OrbitSkin(id: 0, name: "Comet Blue", color: Color(red: 0.30, green: 0.82, blue: 1.0), unlockScore: 0),
        OrbitSkin(id: 1, name: "Ember Gold", color: Color(red: 1.0, green: 0.82, blue: 0.28), unlockScore: 25),
        OrbitSkin(id: 2, name: "Nova Violet", color: Color(red: 0.72, green: 0.42, blue: 1.0), unlockScore: 60),
        OrbitSkin(id: 3, name: "Aurora Green", color: Color(red: 0.30, green: 0.95, blue: 0.68), unlockScore: 120),
        OrbitSkin(id: 4, name: "Solstice Red", color: Color(red: 1.0, green: 0.32, blue: 0.42), unlockScore: 220),
        OrbitSkin(id: 5, name: "Prism White", color: Color(white: 0.97), unlockScore: 400)
    ]

    /// Pulse orbs read violet, distinct from gold embers and cyan shields.
    static let orbColor = Color(red: 0.72, green: 0.42, blue: 1.0)

    static let trails: [TrailStyle] = [
        TrailStyle(id: "comet", name: "Comet", cost: 0),
        TrailStyle(id: "ion", name: "Ion Ribbon", cost: 30),
        TrailStyle(id: "plasma", name: "Plasma Pulse", cost: 60),
        TrailStyle(id: "nova", name: "Nova Spark", cost: 120),
        TrailStyle(id: "spectrum", name: "Spectrum", cost: 220)
    ]

    static let sunThemes: [SunTheme] = [
        SunTheme(id: "solarFlare", name: "Solar Flare", cost: 0,
                core: Color(red: 1, green: 0.95, blue: 0.83),
                mid: Color(red: 1, green: 0.58, blue: 0.16),
                edge: Color(red: 0.77, green: 0.16, blue: 0.1),
                glow: .orange),
        SunTheme(id: "blueGiant", name: "Blue Giant", cost: 30,
                core: Color(red: 0.85, green: 0.95, blue: 1.0),
                mid: Color(red: 0.25, green: 0.55, blue: 0.95),
                edge: Color(red: 0.05, green: 0.12, blue: 0.45),
                glow: Color(red: 0.3, green: 0.6, blue: 1.0)),
        SunTheme(id: "emeraldNova", name: "Emerald Nova", cost: 60,
                core: Color(red: 0.85, green: 1.0, blue: 0.9),
                mid: Color(red: 0.15, green: 0.85, blue: 0.55),
                edge: Color(red: 0.03, green: 0.35, blue: 0.22),
                glow: Color(red: 0.2, green: 0.9, blue: 0.55)),
        SunTheme(id: "violetDwarf", name: "Violet Dwarf", cost: 120,
                core: Color(red: 0.95, green: 0.85, blue: 1.0),
                mid: Color(red: 0.55, green: 0.25, blue: 0.95),
                edge: Color(red: 0.25, green: 0.05, blue: 0.45),
                glow: Color(red: 0.6, green: 0.3, blue: 1.0)),
        SunTheme(id: "prismStar", name: "Prism Star", cost: 220,
                core: .white, mid: .white, edge: .white, glow: .white,
                isPrismatic: true)
    ]

    static let starfieldThemes: [StarfieldTheme] = [
        StarfieldTheme(id: "starlight", name: "Starlight", cost: 0,
                       style: .palette([.white])),
        StarfieldTheme(id: "warmDust", name: "Warm Dust", cost: 30,
                       style: .palette([Color(red: 1, green: 0.85, blue: 0.6),
                                        Color(red: 1, green: 0.7, blue: 0.4), .white])),
        StarfieldTheme(id: "coolNebula", name: "Cool Nebula", cost: 60,
                       style: .palette([Color(red: 0.55, green: 0.75, blue: 1.0),
                                        Color(red: 0.72, green: 0.55, blue: 1.0), .white])),
        StarfieldTheme(id: "aurora", name: "Aurora", cost: 120,
                       style: .palette([Color(red: 0.4, green: 1.0, blue: 0.75),
                                        Color(red: 0.4, green: 0.85, blue: 1.0), .white])),
        StarfieldTheme(id: "chromatic", name: "Chromatic", cost: 220, style: .chromatic)
    ]

    // MARK: Published state
    @Published var phase: GamePhase = .menu
    @Published var size: CGSize = .zero
    @Published var time: Double = 0
    @Published var shake: Double = 0

    @Published var score: Int = 0
    @Published var emberCount: Int = 0
    @Published var emberBalance: Int = 0
    @Published var newlyUnlocked: OrbitSkin?

    /// The level of play. Persisted so the player's choice survives relaunch.
    @Published var difficulty: Difficulty = .normal
    /// Best score per level, so each difficulty keeps its own record.
    @Published var bests: [Difficulty: Int] = [:]
    /// Best on the level that was actually just played, frozen at game over so the
    /// results panel stays truthful if the player switches level before retrying.
    @Published var lastRunBest: Int = 0
    /// True when the most recent run strictly beat the previous best on that level.
    @Published var didSetNewBest: Bool = false

    /// Best on the level currently selected.
    var best: Int { bests[difficulty] ?? 0 }
    /// Highest best across every level — what color unlocks are measured against, so
    /// grinding Easy can't cheaply unlock everything.
    var bestOverall: Int { bests.values.max() ?? 0 }
    /// True when there is anything worth erasing (drives the "START OVER" button).
    var hasProgress: Bool {
        bestOverall > 0 || emberBalance > 0 || unlockedTrailIDs.count > 1
            || unlockedSunThemeIDs.count > 1 || unlockedStarfieldThemeIDs.count > 1
    }

    @Published var shipRing: Int = 0
    @Published var shipRingAnim: Double = 0
    @Published var shipAngle: Double = 0
    @Published var shieldActive: Bool = false

    /// Pulse orbs in hand. Spend one to detonate the flare ahead of the ship.
    @Published var orbCount: Int = 0

    /// Most orbs the player can stockpile at once.
    let maxOrbs = 3

    /// Seconds remaining before the sundiver starts moving after a run begins.
    @Published var startCountdown: Double = 0

    @Published var items: [TrackItem] = []
    @Published var particles: [Particle] = []
    @Published var shockwaves: [Shockwave] = []
    @Published var backgroundStars: [BackgroundStar] = []

    @Published var selectedSkinIndex: Int = 0
    @Published var selectedTrailID: String = "comet"
    @Published var unlockedTrailIDs: Set<String> = ["comet"]
    @Published var selectedSunThemeID: String = "solarFlare"
    @Published var unlockedSunThemeIDs: Set<String> = ["solarFlare"]
    @Published var selectedStarfieldThemeID: String = "starlight"
    @Published var unlockedStarfieldThemeIDs: Set<String> = ["starlight"]

    // MARK: Tuning
    private let shipPixelRadius: CGFloat = 9
    private let lookahead = 3.6
    private var nextSpawnAngle: [Double] = [0.9, 1.6]

    /// Tuning for the level currently selected.
    private var tuning: DifficultyTuning { difficulty.tuning }

    private let defaults = UserDefaults.standard

    /// UserDefaults key holding the best score for one level.
    private static func bestKey(_ level: Difficulty) -> String {
        "sundiver.best.\(level.rawValue)"
    }

    /// Every key this game writes, used by `resetProgress()`. "sundiver.best" is the
    /// pre-difficulty single-best key, still read once for migration.
    private static var allDefaultsKeys: [String] {
        ["sundiver.best", "sundiver.emberBalance", "sundiver.selectedSkinIndex",
         "sundiver.selectedTrailID", "sundiver.unlockedTrailIDs", "sundiver.difficulty",
         "sundiver.selectedSunThemeID", "sundiver.unlockedSunThemeIDs",
         "sundiver.selectedStarfieldThemeID", "sundiver.unlockedStarfieldThemeIDs"]
        + Difficulty.allCases.map(bestKey)
    }

    init() {
        for level in Difficulty.allCases {
            bests[level] = defaults.integer(forKey: Self.bestKey(level))
        }
        // Carry a pre-difficulty best forward into Normal, whose curve matches the
        // original game exactly. Idempotent, so it is safe to run on every launch.
        let legacyBest = defaults.integer(forKey: "sundiver.best")
        if legacyBest > bests[.normal, default: 0] {
            bests[.normal] = legacyBest
            defaults.set(legacyBest, forKey: Self.bestKey(.normal))
        }

        if let raw = defaults.string(forKey: "sundiver.difficulty"),
           let saved = Difficulty(rawValue: raw) {
            difficulty = saved
        }

        emberBalance = defaults.integer(forKey: "sundiver.emberBalance")
        selectedSkinIndex = defaults.integer(forKey: "sundiver.selectedSkinIndex")
        selectedTrailID = defaults.string(forKey: "sundiver.selectedTrailID") ?? "comet"
        if let stored = defaults.array(forKey: "sundiver.unlockedTrailIDs") as? [String] {
            unlockedTrailIDs = Set(stored).union(["comet"])
        }

        selectedSunThemeID = defaults.string(forKey: "sundiver.selectedSunThemeID") ?? "solarFlare"
        if let stored = defaults.array(forKey: "sundiver.unlockedSunThemeIDs") as? [String] {
            unlockedSunThemeIDs = Set(stored).union(["solarFlare"])
        }

        selectedStarfieldThemeID = defaults.string(forKey: "sundiver.selectedStarfieldThemeID") ?? "starlight"
        if let stored = defaults.array(forKey: "sundiver.unlockedStarfieldThemeIDs") as? [String] {
            unlockedStarfieldThemeIDs = Set(stored).union(["starlight"])
        }

        seedBackgroundStars()
    }

    // MARK: Difficulty

    func selectDifficulty(_ level: Difficulty) {
        guard phase != .playing, level != difficulty else { return }
        difficulty = level
        defaults.set(level.rawValue, forKey: "sundiver.difficulty")
    }

    // MARK: Start over

    /// Erases every scrap of saved progress and returns the game to a fresh-install
    /// state. Destructive and irreversible — callers must confirm with the player first.
    func resetProgress() {
        for key in Self.allDefaultsKeys { defaults.removeObject(forKey: key) }

        bests = [:]
        lastRunBest = 0
        didSetNewBest = false
        emberBalance = 0
        difficulty = .normal
        selectedSkinIndex = 0
        selectedTrailID = "comet"
        unlockedTrailIDs = ["comet"]
        selectedSunThemeID = "solarFlare"
        unlockedSunThemeIDs = ["solarFlare"]
        selectedStarfieldThemeID = "starlight"
        unlockedStarfieldThemeIDs = ["starlight"]

        // Drop any run in progress and go back to a clean menu.
        phase = .menu
        score = 0
        emberCount = 0
        shipAngle = 0
        shipRing = 0
        shipRingAnim = 0
        shieldActive = false
        orbCount = 0
        startCountdown = 0
        items = []
        particles = []
        shockwaves = []
        nextSpawnAngle = [0.9, 1.6]
        shake = 0
        newlyUnlocked = nil
    }

    private func seedBackgroundStars() {
        backgroundStars = (0..<70).map { _ in
            BackgroundStar(
                angle: Double.random(in: 0...(2 * .pi)),
                radius: Double.random(in: 60...560),
                alpha: Double.random(in: 0.2...0.9),
                size: CGFloat.random(in: 1...2.6),
                hueSeed: Double.random(in: 0...1)
            )
        }
    }

    // MARK: Derived
    var center: CGPoint { CGPoint(x: size.width / 2, y: size.height / 2) }
    var minDimension: CGFloat { min(size.width, size.height) }

    func ringRadius(_ ring: Int) -> CGFloat {
        ring == 0 ? minDimension * 0.24 : minDimension * 0.38
    }

    var shipRadiusOnScreen: CGFloat {
        let t = CGFloat(shipRingAnim)
        return ringRadius(0) + (ringRadius(1) - ringRadius(0)) * t
    }

    var shipPosition: CGPoint {
        pointOnRing(shipAngle, shipRadiusOnScreen)
    }

    func pointOnRing(_ angle: Double, _ radius: CGFloat) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }

    var activeSkin: OrbitSkin {
        Self.skins.first { $0.id == selectedSkinIndex } ?? Self.skins[0]
    }

    var shipColor: Color { activeSkin.color }

    func isUnlocked(_ skin: OrbitSkin) -> Bool { bestOverall >= skin.unlockScore }

    var nextLockedSkin: OrbitSkin? {
        Self.skins.first { !isUnlocked($0) }
    }

    func selectSkin(_ id: Int) {
        guard let skin = Self.skins.first(where: { $0.id == id }), isUnlocked(skin) else { return }
        selectedSkinIndex = id
        defaults.set(id, forKey: "sundiver.selectedSkinIndex")
    }

    func isTrailOwned(_ trail: TrailStyle) -> Bool { unlockedTrailIDs.contains(trail.id) }

    func purchaseTrail(_ trail: TrailStyle) {
        guard !isTrailOwned(trail), emberBalance >= trail.cost else { return }
        emberBalance -= trail.cost
        unlockedTrailIDs.insert(trail.id)
        persistWallet()
    }

    func selectTrail(_ id: String) {
        guard unlockedTrailIDs.contains(id) else { return }
        selectedTrailID = id
        defaults.set(id, forKey: "sundiver.selectedTrailID")
    }

    var activeSunTheme: SunTheme {
        Self.sunThemes.first { $0.id == selectedSunThemeID } ?? Self.sunThemes[0]
    }

    func isSunThemeOwned(_ theme: SunTheme) -> Bool { unlockedSunThemeIDs.contains(theme.id) }

    func purchaseSunTheme(_ theme: SunTheme) {
        guard !isSunThemeOwned(theme), emberBalance >= theme.cost else { return }
        emberBalance -= theme.cost
        unlockedSunThemeIDs.insert(theme.id)
        persistWallet()
    }

    func selectSunTheme(_ id: String) {
        guard unlockedSunThemeIDs.contains(id) else { return }
        selectedSunThemeID = id
        defaults.set(id, forKey: "sundiver.selectedSunThemeID")
    }

    var activeStarfieldTheme: StarfieldTheme {
        Self.starfieldThemes.first { $0.id == selectedStarfieldThemeID } ?? Self.starfieldThemes[0]
    }

    func isStarfieldThemeOwned(_ theme: StarfieldTheme) -> Bool { unlockedStarfieldThemeIDs.contains(theme.id) }

    func purchaseStarfieldTheme(_ theme: StarfieldTheme) {
        guard !isStarfieldThemeOwned(theme), emberBalance >= theme.cost else { return }
        emberBalance -= theme.cost
        unlockedStarfieldThemeIDs.insert(theme.id)
        persistWallet()
    }

    func selectStarfieldTheme(_ id: String) {
        guard unlockedStarfieldThemeIDs.contains(id) else { return }
        selectedStarfieldThemeID = id
        defaults.set(id, forKey: "sundiver.selectedStarfieldThemeID")
    }

    private func persistWallet() {
        defaults.set(emberBalance, forKey: "sundiver.emberBalance")
        defaults.set(Array(unlockedTrailIDs), forKey: "sundiver.unlockedTrailIDs")
        defaults.set(Array(unlockedSunThemeIDs), forKey: "sundiver.unlockedSunThemeIDs")
        defaults.set(Array(unlockedStarfieldThemeIDs), forKey: "sundiver.unlockedStarfieldThemeIDs")
    }

    // MARK: Game flow
    func handleTap() {
        switch phase {
        case .menu, .gameOver:
            startGame()
        case .playing:
            shipRing = 1 - shipRing
            burstParticles(at: shipPosition, color: shipColor, count: 6)
        }
    }

    /// Spend a pulse orb to destroy the flare blocking the way ahead. Prefers the
    /// ship's own path — that's the one about to end the run — and falls back to the
    /// other path when the current one is already clear.
    func detonateOrb() {
        guard phase == .playing, orbCount > 0 else { return }
        guard let index = nearestFlareAheadIndex(preferring: shipRing) else { return }

        orbCount -= 1
        let hit = items[index]
        items[index].collected = true

        let point = pointOnRing(hit.angle, ringRadius(hit.ring))
        shockwaves.append(Shockwave(pos: point, color: Self.orbColor))
        burstParticles(at: point, color: Self.orbColor, count: 16)
        burstParticles(at: point, color: .white, count: 8)
        shake = 0.5
    }

    /// Index of the closest flare still in front of the ship, searching the preferred
    /// ring first. A flare the ship is already inside still counts — it is the threat.
    private func nearestFlareAheadIndex(preferring ring: Int) -> Int? {
        func closest(on ring: Int?) -> Int? {
            items.indices
                .filter { i in
                    let item = items[i]
                    guard item.kind == .flare, !item.collected else { return false }
                    if let ring, item.ring != ring { return false }
                    return item.angle + item.halfWidth > shipAngle
                }
                .min { items[$0].angle < items[$1].angle }
        }
        return closest(on: ring) ?? closest(on: nil)
    }

    private func startGame() {
        newlyUnlocked = nil
        didSetNewBest = false
        score = 0
        emberCount = 0
        shipAngle = 0
        shipRing = 0
        shipRingAnim = 0
        shieldActive = false
        orbCount = tuning.startingOrbs
        items = []
        particles = []
        shockwaves = []
        nextSpawnAngle = [0.9, 1.6]
        startCountdown = tuning.startDelay
        phase = .playing
        // Fill the visible track up front so the player can read the first
        // hazards while the ship is still held in place.
        spawnIfNeeded()
    }

    private func endGame() {
        phase = .gameOver
        emberBalance += emberCount
        persistWallet()

        // Records are per level, but unlocks are measured against the best of all levels.
        let previousOverall = bestOverall
        didSetNewBest = score > best && score > 0
        if didSetNewBest {
            bests[difficulty] = score
            defaults.set(score, forKey: Self.bestKey(difficulty))
        }
        lastRunBest = best

        if let unlocked = Self.skins.last(where: { $0.unlockScore > previousOverall && $0.unlockScore <= bestOverall }) {
            newlyUnlocked = unlocked
        }
    }

    // MARK: Update loop
    func update(_ dt: Double) {
        let clampedDt = min(dt, 1.0 / 20.0)
        time += clampedDt
        shake = max(0, shake - clampedDt * 2.5)
        shipRingAnim += (Double(shipRing) - shipRingAnim) * min(1, clampedDt * 12)
        updateParticles(clampedDt)
        updateShockwaves(clampedDt)

        guard phase == .playing, size.width > 0 else { return }

        // Hold the ship still for a beat at the start of a run so the player
        // has time to react before the dive begins.
        if startCountdown > 0 {
            startCountdown = max(0, startCountdown - clampedDt)
            return
        }

        // Blend the lane scale across `shipRingAnim` so the pace eases through a dive
        // instead of snapping the instant the ring flips.
        let laneScale = tuning.innerLaneSpeed
            + (tuning.outerLaneSpeed - tuning.innerLaneSpeed) * shipRingAnim
        let speed = (tuning.baseAngularSpeed + min(shipAngle * tuning.speedRamp, tuning.maxSpeedBoost)) * laneScale
        shipAngle += speed * clampedDt
        score = Int(shipAngle * 12)

        spawnIfNeeded()
        checkCollisions()
        items.removeAll { $0.angle < shipAngle - 1.2 || $0.collected }
    }

    private func updateParticles(_ dt: Double) {
        for i in particles.indices.reversed() {
            particles[i].pos.x += particles[i].vel.dx * dt
            particles[i].pos.y += particles[i].vel.dy * dt
            particles[i].life -= dt
            if particles[i].life <= 0 { particles.remove(at: i) }
        }
    }

    private func updateShockwaves(_ dt: Double) {
        for i in shockwaves.indices.reversed() {
            shockwaves[i].age += dt
            if shockwaves[i].age >= shockwaves[i].duration { shockwaves.remove(at: i) }
        }
    }

    private func burstParticles(at point: CGPoint, color: Color, count: Int) {
        for _ in 0..<count {
            let a = Double.random(in: 0...(2 * .pi))
            let speed = Double.random(in: 40...140)
            particles.append(Particle(
                pos: point,
                vel: CGVector(dx: cos(a) * speed, dy: sin(a) * speed),
                color: color,
                size: CGFloat.random(in: 2...4),
                life: Double.random(in: 0.3...0.6),
                maxLife: 0.6
            ))
        }
    }

    private func spawnGap(for ring: Int) -> Double {
        max(tuning.minSpawnGap, tuning.startSpawnGap - shipAngle * tuning.gapTighten)
    }

    private func spawnIfNeeded() {
        let horizon = shipAngle + lookahead
        // Fill the two paths in angle order rather than one whole path then the
        // other. Each new slot can then see what the opposite path has already
        // committed to around it, which is what makes the clearance rule in
        // `flareSlideTarget` actually hold in both directions.
        while let ring = ringNeedingSlot(before: horizon) {
            spawnSlot(on: ring)
        }
    }

    private func ringNeedingSlot(before horizon: Double) -> Int? {
        let due0 = nextSpawnAngle[0] < horizon
        let due1 = nextSpawnAngle[1] < horizon
        switch (due0, due1) {
        case (false, false): return nil
        case (true, false):  return 0
        case (false, true):  return 1
        case (true, true):   return nextSpawnAngle[0] <= nextSpawnAngle[1] ? 0 : 1
        }
    }

    private func spawnSlot(on ring: Int) {
        let angle = nextSpawnAngle[ring]
        let gap = spawnGap(for: ring)
        let roll = Double.random(in: 0...1)

        if roll < tuning.flareChance {
            let halfWidth = Double.random(in: tuning.flareHalfWidth)
            // Never seal off both paths at once. If the opposite path is hazardous
            // here, slide this flare forward to where a real dive window survives
            // and re-roll the slot there.
            if let slid = flareSlideTarget(ring: ring, angle: angle, halfWidth: halfWidth) {
                nextSpawnAngle[ring] = slid
                return
            }
            items.append(TrackItem(kind: .flare, ring: ring, angle: angle, halfWidth: halfWidth))
            nextSpawnAngle[ring] = angle + gap + halfWidth
        } else if roll < 1 - tuning.shieldChance - tuning.orbChance {
            items.append(TrackItem(kind: .ember, ring: ring, angle: angle))
            nextSpawnAngle[ring] = angle + gap * 0.6
        } else if roll < 1 - tuning.orbChance {
            items.append(TrackItem(kind: .shield, ring: ring, angle: angle))
            nextSpawnAngle[ring] = angle + gap * 0.9
        } else {
            items.append(TrackItem(kind: .orb, ring: ring, angle: angle))
            nextSpawnAngle[ring] = angle + gap * 0.9
        }
    }

    /// Radians of track the ship's own body covers on a ring. A flare's killing span
    /// is this much wider than the arc that gets drawn.
    private func shipAngularRadius(on ring: Int) -> Double {
        let r = ringRadius(ring)
        guard r > 0 else { return 0.10 }
        return Double(shipPixelRadius / r)
    }

    /// Fastest the dive can be travelling at a point on the track, taking the quicker
    /// of the two paths — so clearances are sized for the worst case.
    private func worstCaseSpeed(at angle: Double) -> Double {
        let ramped = tuning.baseAngularSpeed + min(angle * tuning.speedRamp, tuning.maxSpeedBoost)
        return ramped * max(tuning.innerLaneSpeed, tuning.outerLaneSpeed)
    }

    /// Clear track the player needs between a flare on one path and the next flare on
    /// the other: room for the ship's body on both paths, plus `minSwitchWindow`
    /// seconds of travel to actually make the dive.
    private func requiredLaneClearance(at angle: Double) -> Double {
        shipAngularRadius(on: 0) + shipAngularRadius(on: 1)
            + tuning.minSwitchWindow * worstCaseSpeed(at: angle)
    }

    /// Where a flare has to move to so the opposite path stays open, or nil when the
    /// proposed spot is already safe. Track angles only ever increase, so this
    /// compares them linearly rather than wrapping.
    private func flareSlideTarget(ring: Int, angle: Double, halfWidth: Double) -> Double? {
        let other = 1 - ring
        let clearance = requiredLaneClearance(at: angle)
        var target = angle
        var moved = false

        // One pass per blocker; the bound just stops a pathological chain.
        for _ in 0..<8 {
            guard let blocker = items.first(where: { item in
                item.ring == other && item.kind == .flare && !item.collected &&
                abs(item.angle - target) < item.halfWidth + halfWidth + clearance
            }) else { break }
            target = blocker.angle + blocker.halfWidth + halfWidth + clearance
            moved = true
        }
        return moved ? target : nil
    }

    private func angularDiff(_ a: Double, _ b: Double) -> Double {
        var d = (a - b).truncatingRemainder(dividingBy: 2 * .pi)
        if d > .pi { d -= 2 * .pi }
        if d < -.pi { d += 2 * .pi }
        return d
    }

    private func checkCollisions() {
        let ringPixelRadius = ringRadius(shipRing)

        for i in items.indices {
            guard items[i].ring == shipRing, !items[i].collected else { continue }
            let diff = abs(angularDiff(items[i].angle, shipAngle))
            let arcDist = diff * Double(ringPixelRadius)

            switch items[i].kind {
            case .flare:
                let hazardHalfWidthPixels = items[i].halfWidth * Double(ringPixelRadius)
                if arcDist < Double(shipPixelRadius) + hazardHalfWidthPixels {
                    if shieldActive {
                        shieldActive = false
                        items[i].collected = true
                        shake = 0.6
                        burstParticles(at: shipPosition, color: .white, count: 14)
                    } else {
                        shake = 1.0
                        burstParticles(at: shipPosition, color: Color(red: 1, green: 0.3, blue: 0.35), count: 20)
                        endGame()
                        return
                    }
                }
            case .ember:
                if arcDist < Double(shipPixelRadius) + 16 {
                    items[i].collected = true
                    emberCount += 1
                    burstParticles(at: shipPosition, color: Color(red: 1, green: 0.82, blue: 0.3), count: 8)
                }
            case .shield:
                if arcDist < Double(shipPixelRadius) + 16 {
                    items[i].collected = true
                    shieldActive = true
                    burstParticles(at: shipPosition, color: .white, count: 10)
                }
            case .orb:
                if arcDist < Double(shipPixelRadius) + 16 {
                    items[i].collected = true
                    orbCount = min(maxOrbs, orbCount + 1)
                    burstParticles(at: shipPosition, color: Self.orbColor, count: 12)
                }
            }
        }
    }
}
