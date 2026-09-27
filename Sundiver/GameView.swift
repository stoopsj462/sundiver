//
//  GameView.swift
//  Sundiver
//

import SwiftUI

struct GameView: View {
    @StateObject private var model = GameModel()
    @State private var showShop = false
    @State private var showReset = false
    @State private var lastTimestamp: Date?

    /// True while a modal owns the screen, so a stray tap can't start a run behind it.
    private var isModalUp: Bool { showShop || showReset }

    private let spaceTop = Color(red: 0.02, green: 0.02, blue: 0.06)
    private let spaceBottom = Color(red: 0.01, green: 0.01, blue: 0.02)
    private let flareColor = Color(red: 1.0, green: 0.28, blue: 0.24)
    private let emberColor = Color(red: 1.0, green: 0.82, blue: 0.3)
    private let cyan = Color(red: 0.3, green: 0.85, blue: 1.0)

    var body: some View {
        ZStack {
            LinearGradient(colors: [spaceTop, spaceBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            TimelineView(.animation) { timeline in
                Canvas { canvas, canvasSize in
                    if model.size != canvasSize {
                        DispatchQueue.main.async { model.size = canvasSize }
                    }
                    drawGame(in: &canvas, size: canvasSize)
                }
                .onChange(of: timeline.date) { newDate in
                    let dt = lastTimestamp.map { newDate.timeIntervalSince($0) } ?? 1.0 / 60.0
                    lastTimestamp = newDate
                    model.update(dt)
                }
            }
            .ignoresSafeArea()

            GameOverlay(
                model: model,
                gold: emberColor,
                cyan: cyan,
                danger: flareColor,
                onOpenShop: { showShop = true },
                onStartOver: { showReset = true }
            )

            if showShop {
                ShopView(model: model, isPresented: $showShop)
            }

            if showReset {
                ResetConfirm(model: model, danger: flareColor, isPresented: $showReset)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isModalUp { model.handleTap() }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
    }

    private func drawGame(in canvas: inout GraphicsContext, size: CGSize) {
        guard model.size.width > 0 else { return }
        var context = canvas
        if model.shake > 0 {
            let amp = model.shake * 10
            let dx = CGFloat.random(in: -amp...amp)
            let dy = CGFloat.random(in: -amp...amp)
            context.translateBy(x: dx, y: dy)
        }
        drawBackgroundStars(&context)
        drawRings(&context)
        drawSun(&context)
        drawItems(&context)
        drawShip(&context)
        drawShockwaves(&context)
        drawParticles(&context)
    }

    private func drawShockwaves(_ context: inout GraphicsContext) {
        for wave in model.shockwaves {
            let t = min(1, wave.age / wave.duration)
            let radius = 12 + t * 78
            let rect = CGRect(x: wave.pos.x - radius, y: wave.pos.y - radius,
                              width: radius * 2, height: radius * 2)
            context.stroke(Path(ellipseIn: rect),
                           with: .color(wave.color.opacity((1 - t) * 0.85)),
                           lineWidth: 3 * (1 - t) + 1)
        }
    }

    private func drawBackgroundStars(_ context: inout GraphicsContext) {
        let center = model.center
        let drift = model.time * 0.015
        let theme = model.activeStarfieldTheme
        for star in model.backgroundStars {
            let a = star.angle + drift
            let p = CGPoint(x: center.x + cos(a) * star.radius, y: center.y + sin(a) * star.radius)
            let twinkle = 0.6 + 0.4 * sin(model.time * 2 + star.angle * 5)
            let rect = CGRect(x: p.x - star.size / 2, y: p.y - star.size / 2, width: star.size, height: star.size)
            let color = starColor(theme: theme, star: star)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(star.alpha * twinkle)))
        }
    }

    /// Resolves a star's color for the active theme. Palette themes key a fixed color
    /// off the star's own `hueSeed` so it doesn't flicker between colors frame to
    /// frame; the chromatic theme instead cycles hue continuously over time.
    private func starColor(theme: StarfieldTheme, star: BackgroundStar) -> Color {
        switch theme.style {
        case .palette(let colors):
            guard !colors.isEmpty else { return .white }
            let index = min(colors.count - 1, Int(star.hueSeed * Double(colors.count)))
            return colors[index]
        case .chromatic:
            let hue = (model.time * 0.05 + star.hueSeed).truncatingRemainder(dividingBy: 1.0)
            return Color(hue: hue, saturation: 0.65, brightness: 1.0)
        }
    }

    private func drawRings(_ context: inout GraphicsContext) {
        for ring in 0...1 {
            let r = model.ringRadius(ring)
            let rect = CGRect(x: model.center.x - r, y: model.center.y - r, width: r * 2, height: r * 2)
            context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.08)), lineWidth: 2)
        }
    }

    private func drawSun(_ context: inout GraphicsContext) {
        let center = model.center
        let base = model.minDimension * 0.14
        let pulse = base * (1 + 0.04 * sin(model.time * 1.6))
        let theme = model.activeSunTheme

        // "Prism Star" cycles its whole gradient through hue instead of using the
        // theme's static core/mid/edge/glow colors.
        let bodyColors: [Color]
        let glowColor: Color
        if theme.isPrismatic {
            bodyColors = prismaticColors()
            glowColor = bodyColors[0]
        } else {
            bodyColors = [theme.core, theme.mid, theme.edge]
            glowColor = theme.glow
        }

        let glowRect = CGRect(x: center.x - pulse * 1.9, y: center.y - pulse * 1.9, width: pulse * 3.8, height: pulse * 3.8)
        context.fill(
            Path(ellipseIn: glowRect),
            with: .radialGradient(
                Gradient(colors: [glowColor.opacity(0.35), .clear]),
                center: center, startRadius: 0, endRadius: pulse * 1.9
            )
        )

        let bodyRect = CGRect(x: center.x - pulse, y: center.y - pulse, width: pulse * 2, height: pulse * 2)
        context.fill(
            Path(ellipseIn: bodyRect),
            with: .radialGradient(
                Gradient(colors: bodyColors),
                center: CGPoint(x: center.x - pulse * 0.3, y: center.y - pulse * 0.3),
                startRadius: 0, endRadius: pulse * 1.3
            )
        )
    }

    private func prismaticColors() -> [Color] {
        stride(from: 0.0, to: 3.0, by: 1.0).map { i in
            Color(hue: (model.time * 0.08 + i / 3.0).truncatingRemainder(dividingBy: 1.0),
                  saturation: 0.75, brightness: 1.0)
        }
    }

    private func drawItems(_ context: inout GraphicsContext) {
        for item in model.items where !item.collected {
            let radius = model.ringRadius(item.ring)
            switch item.kind {
            case .flare:
                drawFlare(&context, ring: item.ring, radius: radius, angle: item.angle, halfWidth: item.halfWidth)
            case .ember:
                let p = model.pointOnRing(item.angle, radius)
                drawEmber(&context, at: p, color: emberColor)
            case .shield:
                let p = model.pointOnRing(item.angle, radius)
                drawEmber(&context, at: p, color: cyan)
            case .orb:
                let p = model.pointOnRing(item.angle, radius)
                drawOrb(&context, at: p)
            }
        }
    }

    private func drawFlare(_ context: inout GraphicsContext, ring: Int, radius: CGFloat, angle: Double, halfWidth: Double) {
        let center = model.center
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: .radians(angle - halfWidth), endAngle: .radians(angle + halfWidth), clockwise: false)
        context.stroke(path, with: .color(flareColor), style: StrokeStyle(lineWidth: 14, lineCap: .round))
        context.stroke(path, with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }

    private func drawEmber(_ context: inout GraphicsContext, at p: CGPoint, color: Color) {
        let glowRect = CGRect(x: p.x - 16, y: p.y - 16, width: 32, height: 32)
        context.fill(
            Path(ellipseIn: glowRect),
            with: .radialGradient(Gradient(colors: [color.opacity(0.8), .clear]), center: p, startRadius: 0, endRadius: 16)
        )
        let s: CGFloat = 7
        var path = Path()
        path.move(to: CGPoint(x: p.x, y: p.y - s))
        path.addLine(to: CGPoint(x: p.x + s, y: p.y))
        path.addLine(to: CGPoint(x: p.x, y: p.y + s))
        path.addLine(to: CGPoint(x: p.x - s, y: p.y))
        path.closeSubpath()
        context.fill(path, with: .color(color))
        context.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)), with: .color(.white))
    }

    /// A pulse orb: a violet core inside a slowly breathing ring, so it reads as a
    /// held charge rather than another collectible.
    private func drawOrb(_ context: inout GraphicsContext, at p: CGPoint) {
        let color = GameModel.orbColor
        let glowRect = CGRect(x: p.x - 18, y: p.y - 18, width: 36, height: 36)
        context.fill(
            Path(ellipseIn: glowRect),
            with: .radialGradient(Gradient(colors: [color.opacity(0.75), .clear]),
                                  center: p, startRadius: 0, endRadius: 18)
        )

        let pulse = 9 + 2 * sin(model.time * 4)
        context.stroke(
            Path(ellipseIn: CGRect(x: p.x - pulse, y: p.y - pulse, width: pulse * 2, height: pulse * 2)),
            with: .color(color.opacity(0.9)), lineWidth: 2
        )
        context.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)),
                     with: .color(.white))
    }

    private func drawShip(_ context: inout GraphicsContext) {
        let p = model.shipPosition
        drawTrail(&context, at: p)

        let glowRect = CGRect(x: p.x - 24, y: p.y - 24, width: 48, height: 48)
        context.fill(
            Path(ellipseIn: glowRect),
            with: .radialGradient(Gradient(colors: [model.shipColor.opacity(0.8), .clear]), center: p, startRadius: 0, endRadius: 24)
        )
        if model.shieldActive {
            context.stroke(Path(ellipseIn: CGRect(x: p.x - 15, y: p.y - 15, width: 30, height: 30)), with: .color(.white.opacity(0.8)), lineWidth: 2)
        }
        context.fill(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)), with: .color(model.shipColor))
        context.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .color(.white))
    }

    private func drawTrail(_ context: inout GraphicsContext, at p: CGPoint) {
        let radius = model.shipRadiusOnScreen
        let a0 = model.shipAngle
        let sweep = 0.55
        let center = model.center

        switch model.selectedTrailID {
        case "ion":
            var path = Path()
            path.addArc(center: center, radius: radius, startAngle: .radians(a0 - sweep), endAngle: .radians(a0), clockwise: false)
            context.stroke(path, with: .color(model.shipColor.opacity(0.55)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        case "plasma":
            for i in 0..<3 {
                let phase = (model.time * 1.5 + Double(i) / 3.0).truncatingRemainder(dividingBy: 1.0)
                let rr = 10 + phase * 22
                let rect = CGRect(x: p.x - rr, y: p.y - rr, width: rr * 2, height: rr * 2)
                context.stroke(Path(ellipseIn: rect), with: .color(model.shipColor.opacity((1 - phase) * 0.5)), lineWidth: 2)
            }
        case "nova":
            let samples = 7
            for i in 1...samples {
                let t = Double(i) / Double(samples)
                let angle = a0 - sweep * t
                let pos = model.pointOnRing(angle, radius)
                let s = CGFloat((1 - t) * 4 + 1)
                context.fill(Path(ellipseIn: CGRect(x: pos.x - s / 2, y: pos.y - s / 2, width: s, height: s)), with: .color(model.shipColor.opacity((1 - t) * 0.85)))
            }
        case "spectrum":
            var path = Path()
            path.addArc(center: center, radius: radius, startAngle: .radians(a0 - sweep), endAngle: .radians(a0), clockwise: false)
            let hues = stride(from: 0.0, to: 6.0, by: 1.0).map { i in
                Color(hue: (model.time * 0.2 + i / 6.0).truncatingRemainder(dividingBy: 1.0), saturation: 0.85, brightness: 1)
            }
            context.stroke(path, with: .linearGradient(Gradient(colors: hues), startPoint: p, endPoint: model.pointOnRing(a0 - sweep, radius)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        default: // comet
            var path = Path()
            path.addArc(center: center, radius: radius, startAngle: .radians(a0 - sweep), endAngle: .radians(a0), clockwise: false)
            context.stroke(path, with: .linearGradient(Gradient(colors: [model.shipColor.opacity(0.55), .clear]), startPoint: p, endPoint: model.pointOnRing(a0 - sweep, radius)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        }
    }

    private func drawParticles(_ context: inout GraphicsContext) {
        for particle in model.particles {
            let alpha = max(0, particle.life / particle.maxLife)
            let rect = CGRect(x: particle.pos.x - particle.size / 2, y: particle.pos.y - particle.size / 2, width: particle.size, height: particle.size)
            context.fill(Path(ellipseIn: rect), with: .color(particle.color.opacity(alpha)))
        }
    }
}

struct GameOverlay: View {
    @ObservedObject var model: GameModel
    let gold: Color
    let cyan: Color
    let danger: Color
    let onOpenShop: () -> Void
    let onStartOver: () -> Void

    var body: some View {
        switch model.phase {
        case .playing:
            HUD(model: model, gold: gold)
        case .menu:
            MenuOverlay(model: model, gold: gold, danger: danger,
                        onOpenShop: onOpenShop, onStartOver: onStartOver)
        case .gameOver:
            GameOverOverlay(model: model, gold: gold, cyan: cyan, danger: danger,
                            onOpenShop: onOpenShop)
        }
    }
}

struct HUD: View {
    @ObservedObject var model: GameModel
    let gold: Color

    var body: some View {
        VStack {
            HStack {
                Text("✦ \(model.emberCount)")
                    .foregroundColor(gold)
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(model.difficulty.name)
                        .foregroundColor(model.difficulty.tint.opacity(0.9))
                        .font(.system(size: 11, weight: .bold))
                    Text("BEST \(model.best)")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .padding(.horizontal, 24)
            Spacer().frame(height: 16)
            Text("\(model.score)")
                .foregroundColor(.white)
                .font(.system(size: 54, weight: .black))
            if model.startCountdown > 0 {
                Text("GET READY")
                    .foregroundColor(model.shipColor.opacity(0.75 + 0.25 * sin(model.time * 8)))
                    .font(.system(size: 18, weight: .bold))
                    .padding(.top, 8)
            }
            Spacer()
            OrbButton(model: model)
                .padding(.bottom, 28)
        }
        .padding(.top, 24)
    }
}

/// Spends a pulse orb on the flare ahead. Always on screen during a run — dimmed at
/// zero — so the player learns the escape exists before they need it.
struct OrbButton: View {
    @ObservedObject var model: GameModel

    var body: some View {
        let ready = model.orbCount > 0
        let color = GameModel.orbColor

        Button(action: { model.detonateOrb() }) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(color.opacity(ready ? 0.9 : 0.3), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    Circle()
                        .fill(ready ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
                Text(ready ? "BLAST ×\(model.orbCount)" : "NO ORBS")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(ready ? .white : .white.opacity(0.35))
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Capsule().fill(color.opacity(ready ? 0.22 : 0.06)))
            .overlay(Capsule().stroke(color.opacity(ready ? 0.7 : 0.15), lineWidth: 1))
            .shadow(color: ready ? color.opacity(0.5) : .clear, radius: 10)
        }
        // Deliberately not `.disabled` — a disabled button would let the tap fall
        // through to the background and flip rings, which is the last thing the
        // player wants mid-dodge. `detonateOrb()` already no-ops at zero.
        .buttonStyle(.plain)
    }
}

struct MenuOverlay: View {
    @ObservedObject var model: GameModel
    let gold: Color
    let danger: Color
    let onOpenShop: () -> Void
    let onStartOver: () -> Void

    var body: some View {
        Panel {
            VStack(spacing: 14) {
                Text("SUNDIVER")
                    .foregroundColor(model.shipColor)
                    .font(.system(size: 52, weight: .black))
                Text("Tap to dive between orbits.\nDodge the flares. Grab the embers.\nBlast a flare with a pulse orb when it gets tight.")
                    .foregroundColor(.white.opacity(0.75))
                    .font(.system(size: 16, weight: .medium))
                    .multilineTextAlignment(.center)

                DifficultyPicker(model: model, gold: gold)

                SkinPicker(model: model)
                ShopButton(balance: model.emberBalance, onClick: onOpenShop)

                if model.hasProgress {
                    StartOverButton(danger: danger, onClick: onStartOver)
                }

                StartPill(text: "TAP TO START", color: model.shipColor, time: model.time)
            }
        }
    }
}

struct GameOverOverlay: View {
    @ObservedObject var model: GameModel
    let gold: Color
    let cyan: Color
    let danger: Color
    let onOpenShop: () -> Void

    var body: some View {
        Panel {
            VStack(spacing: 14) {
                Text(model.didSetNewBest ? "NEW BEST!" : "GAME OVER")
                    .foregroundColor(model.didSetNewBest ? gold : danger)
                    .font(.system(size: 36, weight: .black))

                HStack(spacing: 28) {
                    StatItem(title: "SCORE", value: "\(model.score)", color: .white)
                    StatItem(title: "EMBERS", value: "+\(model.emberCount)", color: gold)
                    StatItem(title: "BEST", value: "\(model.lastRunBest)", color: cyan)
                }

                if let unlock = model.newlyUnlocked {
                    Text("✨ New color unlocked: \(unlock.name)!")
                        .foregroundColor(unlock.color)
                        .font(.system(size: 14, weight: .bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(unlock.color.opacity(0.16))
                        .clipShape(Capsule())
                }

                DifficultyRow(model: model)

                SkinPicker(model: model)
                ShopButton(balance: model.emberBalance, onClick: onOpenShop)
                StartPill(text: "TAP TO RETRY", color: model.shipColor, time: model.time)
            }
        }
    }
}

struct Panel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack {
            Spacer()
            content
                .padding(28)
                .background(Color(red: 0.01, green: 0.01, blue: 0.03).opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .overlay(RoundedRectangle(cornerRadius: 32).stroke(.white.opacity(0.06), lineWidth: 1))
                .padding(24)
            Spacer()
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack {
            Text(value).foregroundColor(color).font(.system(size: 28, weight: .black))
            Text(title).foregroundColor(.white.opacity(0.5)).font(.system(size: 11, weight: .semibold))
        }
    }
}

struct StartPill: View {
    let text: String
    let color: Color
    let time: Double

    var body: some View {
        let opacity = 0.75 + 0.25 * sin(time * 3)
        Text(text)
            .foregroundColor(.black)
            .font(.system(size: 17, weight: .bold))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(color.opacity(opacity))
            .clipShape(Capsule())
    }
}

struct ShopButton: View {
    let balance: Int
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            Text("🛍️ SHOP · ✦ \(balance)")
                .foregroundColor(.white)
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
        }
    }
}

/// Level pills plus a caption naming the record on the selected level.
struct DifficultyPicker: View {
    @ObservedObject var model: GameModel
    let gold: Color

    var body: some View {
        VStack(spacing: 8) {
            DifficultyRow(model: model)
            Text(model.best > 0
                 ? "\(model.difficulty.name) · BEST \(model.best)"
                 : "\(model.difficulty.name) · no record yet")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(model.best > 0 ? gold : .white.opacity(0.5))

            if model.difficulty.tuning.hasAsymmetricLanes {
                Text("outer orbit runs faster than the inner one")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(model.difficulty.tint.opacity(0.8))
            }
        }
    }
}

/// Just the four level pills. Scrolls rather than clipping on the narrowest phones.
struct DifficultyRow: View {
    @ObservedObject var model: GameModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Difficulty.allCases) { level in
                    DifficultyPill(model: model, level: level)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: 360)
    }
}

struct DifficultyPill: View {
    @ObservedObject var model: GameModel
    let level: Difficulty

    var body: some View {
        let selected = model.difficulty == level
        Button(action: { model.selectDifficulty(level) }) {
            Text(level.name)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(selected ? .black : .white.opacity(0.6))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Capsule().fill(selected ? level.tint : Color.white.opacity(0.07)))
                .overlay(Capsule().stroke(.white.opacity(selected ? 0 : 0.12), lineWidth: 1))
                .shadow(color: selected ? level.tint.opacity(0.55) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
    }
}

struct StartOverButton: View {
    let danger: Color
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise")
                Text("START OVER")
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(danger.opacity(0.95))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(danger.opacity(0.13)))
            .overlay(Capsule().stroke(danger.opacity(0.32), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Confirmation gate for the irreversible wipe.
struct ResetConfirm: View {
    @ObservedObject var model: GameModel
    let danger: Color
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.78)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { isPresented = false }

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(danger)

                Text("START OVER?")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.white)

                Text("This erases every best score, your \(model.emberBalance) banked embers, and every color, trail, sun theme, and starfield bought in the shop.\n\nThis can't be undone.")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                HStack(spacing: 12) {
                    ConfirmButton(title: "CANCEL", color: .white.opacity(0.85), filled: false) {
                        isPresented = false
                    }
                    ConfirmButton(title: "ERASE ALL", color: danger, filled: true) {
                        model.resetProgress()
                        isPresented = false
                    }
                }
                .padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: 380)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.06)))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1))
            .padding(24)
            .shadow(color: .black.opacity(0.6), radius: 30)
        }
        .transition(.opacity)
    }
}

struct ConfirmButton: View {
    let title: String
    let color: Color
    let filled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(filled ? .black : color)
                .padding(.horizontal, 22)
                .padding(.vertical, 11)
                .background(Capsule().fill(filled ? color : Color.white.opacity(0.1)))
                .overlay(Capsule().stroke(.white.opacity(filled ? 0 : 0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct SkinPicker: View {
    @ObservedObject var model: GameModel

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ForEach(GameModel.skins) { skin in
                    SkinDot(skin: skin, model: model)
                }
            }
            let caption: String = {
                if let next = model.nextLockedSkin {
                    return "\(model.activeSkin.name) equipped · unlock \u{201c}\(next.name)\u{201d} at \(next.unlockScore)"
                }
                return "\(model.activeSkin.name) equipped · all \(GameModel.skins.count) colors unlocked"
            }()
            Text(caption)
                .foregroundColor(.white.opacity(0.55))
                .font(.system(size: 11, weight: .semibold))
                .multilineTextAlignment(.center)
        }
    }
}

struct SkinDot: View {
    let skin: OrbitSkin
    @ObservedObject var model: GameModel

    var body: some View {
        let unlocked = model.isUnlocked(skin)
        let selected = model.selectedSkinIndex == skin.id
        Button(action: { model.selectSkin(skin.id) }) {
            ZStack {
                Circle().fill(unlocked ? skin.color : Color.white.opacity(0.08))
                if !unlocked {
                    VStack(spacing: 0) {
                        Text("🔒").font(.system(size: 8))
                        Text("\(skin.unlockScore)").font(.system(size: 7, weight: .bold)).foregroundColor(.white.opacity(0.55))
                    }
                }
            }
            .frame(width: 32, height: 32)
            .overlay(Circle().stroke(selected ? Color.white.opacity(0.95) : Color.white.opacity(0.18), lineWidth: selected ? 3 : 1))
        }
        .disabled(!unlocked)
    }
}

#Preview {
    GameView()
}
