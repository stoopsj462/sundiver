//
//  ShopView.swift
//  Sundiver
//

import SwiftUI

struct ShopView: View {
    @ObservedObject var model: GameModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Embers").font(.headline)
                        Spacer()
                        Text("✦ \(model.emberBalance)")
                            .foregroundColor(Color(red: 1, green: 0.82, blue: 0.3))
                            .font(.headline)
                    }
                }

                Section("Comet Trails") {
                    ForEach(GameModel.trails) { trail in
                        TrailRow(model: model, trail: trail)
                    }
                }
            }
            .navigationTitle("Shop")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct TrailRow: View {
    @ObservedObject var model: GameModel
    let trail: TrailStyle

    var body: some View {
        let owned = model.isTrailOwned(trail)
        let selected = model.selectedTrailID == trail.id

        HStack {
            VStack(alignment: .leading) {
                Text(trail.name).font(.body)
                if !owned {
                    Text("✦ \(trail.cost)").font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            if selected {
                Text("Equipped").font(.caption).foregroundColor(.green)
            } else if owned {
                Button("Equip") { model.selectTrail(trail.id) }
            } else {
                Button("Buy") { model.purchaseTrail(trail) }
                    .disabled(model.emberBalance < trail.cost)
            }
        }
    }
}

#Preview {
    ShopView(model: GameModel())
}
