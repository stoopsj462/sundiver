//
//  GameView.swift
//  Sundiver
//

import SwiftUI

struct GameView: View {
    @StateObject private var model = GameModel()
    @State private var showShop = false
    @State private var lastTimestamp: Date?

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

            GameOverlay(model: model, gold: emberColor, cyan: cyan, danger: flareColor, onOpenShop: { showShop = true })
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !showShop { model.handleTap() }
        }
        .sheet(isPresented: $showShop) {
            ShopView(model: model)
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
        drawParticles(&context)
    }

    private func drawBackgroundStars(_ context: inout GraphicsContext) {
        let center = model.center
        let drift = model.time * 0.015
        for star in model.backgroundStars {
            let a = star.angle + drift
            let p = CGPoint(x: center.x + cos(a) * star.radius, y: center.y + sin(a) * star.radius)
            let twinkle = 0.6 + 0.4 * sin(model.time * 2 + star.angle * 5)
            let rect = CGRect(x: p.x - star.size / 2, y: p.y - star.size / 2, width: star.size, height: star.size)
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(star.alpha * twinkle)))
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

        let glowRect = CGRect(x: center.x - pulse * 1.9, y: center.y - pulse * 1.9, width: pulse * 3.8, height: pulse * 3.8)
        context.fill(
            Path(ellipseIn: glowRect),
            with: .radialGradient(
                Gradient(colors: [Color.orange.opacity(0.35), .clear]),
                center: center, startRadius: 0, endRadius: pulse * 1.9
            )
        )

        let bodyRect = CGRect(x: center.x - pulse, y: center.y - pulse, width: pulse * 2, height: pulse * 2)
        context.fill(
            Path(ellipseIn: bodyRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 1, green: 0.95, blue: 0.83),
                    Color(red: 1, green: 0.58, blue: 0.16),
                    Color(red: 0.77, green: 0.16, blue: 0.1)
                ]),
                center: CGPoint(x: center.x - pulse * 0.3, y: center.y - pulse * 0.3),
                startRadius: 0, endRadius: pulse * 1.3
            )
        )
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

    var body: some View {
        switch model.phase {
        case .playing:
            HUD(model: model, gold: gold)
        case .menu:
            MenuOverlay(model: model, gold: gold, onOpenShop: onOpenShop)
        case .gameOver:
            GameOverOverlay(model: model, gold: gold, cyan: cyan, danger: danger, onOpenShop: onOpenShop)
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
                Text("BEST \(model.best)")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 24)
            Spacer().frame(height: 16)
            Text("\(model.score)")
                .foregroundColor(.white)
                .font(.system(size: 54, weight: .black))
            Spacer()
        }
        .padding(.top, 24)
    }
}

struct MenuOverlay: View {
    @ObservedObject var model: GameModel
    let gold: Color
    let onOpenShop: () -> Void

    var body: some View {
        Panel {
            VStack(spacing: 16) {
                Text("SUNDIVER")
                    .foregroundColor(model.shipColor)
                    .font(.system(size: 52, weight: .black))
                Text("Tap to dive between orbits.\nDodge the flares. Grab the embers.")
                    .foregroundColor(.white.opacity(0.75))
                    .font(.system(size: 16, weight: .medium))
                    .multilineTextAlignment(.center)
                if model.best > 0 {
                    Text("BEST  \(model.best)")
                        .foregroundColor(gold)
                        .font(.system(size: 16, weight: .bold))
                }
                SkinPicker(model: model)
                ShopButton(balance: model.emberBalance, onClick: onOpenShop)
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
                let isNewBest = model.score >= model.best && model.score > 0
                Text(isNewBest ? "NEW BEST!" : "GAME OVER")
                    .foregroundColor(isNewBest ? gold : danger)
                    .font(.system(size: 36, weight: .black))

                HStack(spacing: 28) {
                    StatItem(title: "SCORE", value: "\(model.score)", color: .white)
                    StatItem(title: "EMBERS", value: "+\(model.emberCount)", color: gold)
                    StatItem(title: "BEST", value: "\(model.best)", color: cyan)
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
