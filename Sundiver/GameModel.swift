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

struct TrackItem: Identifiable {
    enum Kind { case flare, ember, shield }
    let id = UUID()
    var kind: Kind
    var ring: Int
    var angle: Double
    var halfWidth: Double = 0
    var collected = false
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

    static let trails: [TrailStyle] = [
        TrailStyle(id: "comet", name: "Comet", cost: 0),
        TrailStyle(id: "ion", name: "Ion Ribbon", cost: 30),
        TrailStyle(id: "plasma", name: "Plasma Pulse", cost: 60),
        TrailStyle(id: "nova", name: "Nova Spark", cost: 120),
        TrailStyle(id: "spectrum", name: "Spectrum", cost: 220)
    ]

    // MARK: Published state
    @Published var phase: GamePhase = .menu
    @Published var size: CGSize = .zero
    @Published var time: Double = 0
    @Published var shake: Double = 0

    @Published var score: Int = 0
    @Published var emberCount: Int = 0
    @Published var best: Int = 0
    @Published var emberBalance: Int = 0
    @Published var newlyUnlocked: OrbitSkin?

    @Published var shipRing: Int = 0
    @Published var shipRingAnim: Double = 0
    @Published var shipAngle: Double = 0
    @Published var shieldActive: Bool = false

    @Published var items: [TrackItem] = []
    @Published var particles: [Particle] = []
    @Published var backgroundStars: [BackgroundStar] = []

    @Published var selectedSkinIndex: Int = 0
    @Published var selectedTrailID: String = "comet"
    @Published var unlockedTrailIDs: Set<String> = ["comet"]

    // MARK: Tuning
    private let baseAngularSpeed = 1.05
    private let maxAngularSpeedBoost = 1.55
    private let shipPixelRadius: CGFloat = 9
    private let lookahead = 3.6
    private var nextSpawnAngle: [Double] = [0.9, 1.6]

    private let defaults = UserDefaults.standard

    init() {
        best = defaults.integer(forKey: "sundiver.best")
        emberBalance = defaults.integer(forKey: "sundiver.emberBalance")
        selectedSkinIndex = defaults.integer(forKey: "sundiver.selectedSkinIndex")
        selectedTrailID = defaults.string(forKey: "sundiver.selectedTrailID") ?? "comet"
        if let stored = defaults.array(forKey: "sundiver.unlockedTrailIDs") as? [String] {
            unlockedTrailIDs = Set(stored).union(["comet"])
        }
        seedBackgroundStars()
    }

    private func seedBackgroundStars() {
        backgroundStars = (0..<70).map { _ in
            BackgroundStar(
                angle: Double.random(in: 0...(2 * .pi)),
                radius: Double.random(in: 60...560),
                alpha: Double.random(in: 0.2...0.9),
                size: CGFloat.random(in: 1...2.6)
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

    func isUnlocked(_ skin: OrbitSkin) -> Bool { best >= skin.unlockScore }

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

    private func persistWallet() {
        defaults.set(emberBalance, forKey: "sundiver.emberBalance")
        defaults.set(Array(unlockedTrailIDs), forKey: "sundiver.unlockedTrailIDs")
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

    private func startGame() {
        newlyUnlocked = nil
        score = 0
        emberCount = 0
        shipAngle = 0
        shipRing = 0
        shipRingAnim = 0
        shieldActive = false
        items = []
        particles = []
        nextSpawnAngle = [0.9, 1.6]
        phase = .playing
    }

    private func endGame() {
        phase = .gameOver
        let previousBest = best
        if score > best { best = score }
        emberBalance += emberCount
        persistWallet()
        defaults.set(best, forKey: "sundiver.best")

        if let unlocked = Self.skins.last(where: { $0.unlockScore > previousBest && $0.unlockScore <= best }) {
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

        guard phase == .playing, size.width > 0 else { return }

        let speed = baseAngularSpeed + min(shipAngle * 0.006, maxAngularSpeedBoost)
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
        max(0.62, 1.15 - shipAngle * 0.0025)
    }

    private func spawnIfNeeded() {
        for ring in 0...1 {
            while nextSpawnAngle[ring] < shipAngle + lookahead {
                let angle = nextSpawnAngle[ring]
                let roll = Double.random(in: 0...1)

                if roll < 0.45 {
                    let halfWidth = Double.random(in: 0.10...0.19)
                    if overlapsOtherRing(ring: ring, angle: angle, halfWidth: halfWidth) {
                        items.append(TrackItem(kind: .ember, ring: ring, angle: angle))
                        nextSpawnAngle[ring] += spawnGap(for: ring) * 0.6
                    } else {
                        items.append(TrackItem(kind: .flare, ring: ring, angle: angle, halfWidth: halfWidth))
                        nextSpawnAngle[ring] += spawnGap(for: ring) + halfWidth
                    }
                } else if roll < 0.92 {
                    items.append(TrackItem(kind: .ember, ring: ring, angle: angle))
                    nextSpawnAngle[ring] += spawnGap(for: ring) * 0.6
                } else {
                    items.append(TrackItem(kind: .shield, ring: ring, angle: angle))
                    nextSpawnAngle[ring] += spawnGap(for: ring) * 0.9
                }
            }
        }
    }

    private func overlapsOtherRing(ring: Int, angle: Double, halfWidth: Double) -> Bool {
        let other = 1 - ring
        return items.contains { item in
            item.ring == other && item.kind == .flare &&
            abs(angularDiff(item.angle, angle)) < (item.halfWidth + halfWidth + 0.05)
        }
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
            }
        }
    }
}
