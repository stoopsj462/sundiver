//
//  ShopView.swift
//  Sundiver
//
//  The Ember Shop. Spend banked embers on comet trails.
//  All previews are drawn in code to match the in-game look.
//

import SwiftUI

struct ShopView: View {
    @ObservedObject var model: GameModel
    @Binding var isPresented: Bool

    private let gold = Color(red: 1.0, green: 0.82, blue: 0.28)
    private let panel = Color(red: 0.04, green: 0.04, blue: 0.09)

    var body: some View {
        ZStack {
            // Dim backdrop that also swallows taps so the game doesn't start behind it.
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                header
                Divider().overlay(.white.opacity(0.1))
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        section(title: "Comet Trails") {
                            ForEach(GameModel.trails) { trail in
                                trailCard(trail)
                            }
                        }
                        section(title: "Sun Themes") {
                            ForEach(GameModel.sunThemes) { theme in
                                sunThemeCard(theme)
                            }
                        }
                        section(title: "Starfield") {
                            ForEach(GameModel.starfieldThemes) { theme in
                                starfieldThemeCard(theme)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .frame(maxWidth: 460)
            .background(RoundedRectangle(cornerRadius: 28).fill(panel))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.08), lineWidth: 1))
            .padding(18)
            .shadow(color: .black.opacity(0.6), radius: 30)
        }
        .transition(.opacity)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("EMBER SHOP")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "sparkle")
                Text("\(model.emberBalance)")
            }
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(gold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(gold.opacity(0.15)))

            Button { isPresented = false } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .padding(20)
    }

    // MARK: Section

    private func section<Content: View>(title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.45))
            // A wrapping grid so every card is on screen at once — no sideways
            // scrolling. Adaptive columns fit 3 across on a phone, more on iPad.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96, maximum: 140), spacing: 12)],
                      spacing: 12) {
                content()
            }
        }
    }

    // MARK: Card

    private func trailCard(_ trail: TrailStyle) -> some View {
        let owned = model.isTrailOwned(trail)
        let isSelected = model.selectedTrailID == trail.id
        let affordable = model.emberBalance >= trail.cost

        return Button {
            if owned {
                model.selectTrail(trail.id)
            } else if affordable {
                model.purchaseTrail(trail)
                model.selectTrail(trail.id)
            }
        } label: {
            VStack(spacing: 8) {
                trailPreview(trail)
                    .frame(width: 60, height: 60)

                Text(trail.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                statusLabel(owned: owned, isSelected: isSelected, cost: trail.cost, affordable: affordable)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 132)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.white.opacity(isSelected ? 0.10 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? gold : .white.opacity(0.08),
                            lineWidth: isSelected ? 2 : 1)
            )
            .opacity(owned || affordable ? 1 : 0.55)
        }
        .buttonStyle(.plain)
    }

    private func sunThemeCard(_ theme: SunTheme) -> some View {
        let owned = model.isSunThemeOwned(theme)
        let isSelected = model.selectedSunThemeID == theme.id
        let affordable = model.emberBalance >= theme.cost

        return Button {
            if owned {
                model.selectSunTheme(theme.id)
            } else if affordable {
                model.purchaseSunTheme(theme)
                model.selectSunTheme(theme.id)
            }
        } label: {
            VStack(spacing: 8) {
                sunThemePreview(theme)
                    .frame(width: 60, height: 60)

                Text(theme.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                statusLabel(owned: owned, isSelected: isSelected, cost: theme.cost, affordable: affordable)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 132)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.white.opacity(isSelected ? 0.10 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? gold : .white.opacity(0.08),
                            lineWidth: isSelected ? 2 : 1)
            )
            .opacity(owned || affordable ? 1 : 0.55)
        }
        .buttonStyle(.plain)
    }

    private func starfieldThemeCard(_ theme: StarfieldTheme) -> some View {
        let owned = model.isStarfieldThemeOwned(theme)
        let isSelected = model.selectedStarfieldThemeID == theme.id
        let affordable = model.emberBalance >= theme.cost

        return Button {
            if owned {
                model.selectStarfieldTheme(theme.id)
            } else if affordable {
                model.purchaseStarfieldTheme(theme)
                model.selectStarfieldTheme(theme.id)
            }
        } label: {
            VStack(spacing: 8) {
                starfieldThemePreview(theme)
                    .frame(width: 60, height: 60)

                Text(theme.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                statusLabel(owned: owned, isSelected: isSelected, cost: theme.cost, affordable: affordable)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 132)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.white.opacity(isSelected ? 0.10 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? gold : .white.opacity(0.08),
                            lineWidth: isSelected ? 2 : 1)
            )
            .opacity(owned || affordable ? 1 : 0.55)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statusLabel(owned: Bool, isSelected: Bool, cost: Int, affordable: Bool) -> some View {
        if isSelected {
            label("Equipped", color: gold, filled: true)
        } else if owned {
            label("Equip", color: .white.opacity(0.85), filled: false)
        } else {
            HStack(spacing: 3) {
                Image(systemName: "sparkle").font(.system(size: 10))
                Text("\(cost)").font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundColor(affordable ? gold : .white.opacity(0.4))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(.white.opacity(0.06)))
        }
    }

    private func label(_ text: String, color: Color, filled: Bool) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(filled ? .black : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(filled ? color : Color.white.opacity(0.08)))
    }

    // MARK: Previews (mini versions of the in-game trails)

    private func trailPreview(_ trail: TrailStyle) -> some View {
        let color = model.shipColor
        return ZStack {
            Circle().fill(.white.opacity(0.03))
            switch trail.id {
            case "ion":
                Capsule().fill(color.opacity(0.55)).frame(width: 40, height: 5)
                shipDot(color)
            case "plasma":
                Circle().stroke(color.opacity(0.5), lineWidth: 2).frame(width: 32, height: 32)
                Circle().stroke(color.opacity(0.28), lineWidth: 2).frame(width: 46, height: 46)
                shipDot(color)
            case "nova":
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(color.opacity(0.85 - Double(i) * 0.15))
                        .frame(width: 6 - CGFloat(i), height: 6 - CGFloat(i))
                        .offset(x: -8 - CGFloat(i) * 7, y: 0)
                }
                shipDot(color)
            case "spectrum":
                Capsule()
                    .fill(LinearGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 42, height: 6)
                shipDot(color)
            default: // comet
                Capsule()
                    .fill(LinearGradient(colors: [.clear, color], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 42, height: 6)
                shipDot(color)
            }
        }
    }

    private func shipDot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .shadow(color: color.opacity(0.8), radius: 6)
            .offset(x: 16)
    }

    /// A mini version of the in-game sun, matching `GameView.drawSun`.
    private func sunThemePreview(_ theme: SunTheme) -> some View {
        ZStack {
            Circle().fill(.white.opacity(0.03))
            if theme.isPrismatic {
                Circle()
                    .fill(AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                                          center: .center))
                    .frame(width: 44, height: 44)
            } else {
                Circle()
                    .fill(RadialGradient(colors: [theme.core, theme.mid, theme.edge],
                                         center: .init(x: 0.35, y: 0.35), startRadius: 0, endRadius: 26))
                    .frame(width: 44, height: 44)
                    .shadow(color: theme.glow.opacity(0.7), radius: 8)
            }
        }
    }

    /// A mini scatter of stars in the theme's palette, matching `GameView.starColor`.
    private func starfieldThemePreview(_ theme: StarfieldTheme) -> some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.35))
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) / 8 * 2 * .pi
                let radius: CGFloat = i.isMultiple(of: 2) ? 22 : 13
                let size: CGFloat = i.isMultiple(of: 3) ? 4 : 2.5
                Circle()
                    .fill(starfieldSwatchColor(theme, index: i))
                    .frame(width: size, height: size)
                    .offset(x: cos(angle) * radius, y: sin(angle) * radius)
            }
        }
    }

    private func starfieldSwatchColor(_ theme: StarfieldTheme, index: Int) -> Color {
        switch theme.style {
        case .palette(let colors):
            guard !colors.isEmpty else { return .white }
            return colors[index % colors.count]
        case .chromatic:
            return Color(hue: Double(index) / 8, saturation: 0.65, brightness: 1.0)
        }
    }
}

#Preview {
    ShopView(model: GameModel(), isPresented: .constant(true))
}
