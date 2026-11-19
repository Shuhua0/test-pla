import SwiftUI

struct LaneSel: Identifiable { let id: Int }
struct ItemSel: Identifiable { let id: UUID }

struct ContentView: View {
    var body: some View {
        TabView {
            ListScreen().tabItem { Label("리스트", systemImage: "list.bullet") }
            TimelineScreen().tabItem { Label("타임라인", systemImage: "chart.bar.xaxis") }
        }
    }
}

struct Row: View {
    let s: Slot
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(s.item.title).bold()
                if s.item.helper { Text("🧑‍🔧") }
                if s.saved > 1 { Text("⚡") }
            }
            Text(detail).font(.caption)
            if s.waste > 1 {
                Text("조수 낭비 \(fmt(s.waste))").font(.caption).foregroundColor(.orange)
            }
        }
    }
    var detail: String {
        var t = fmt(s.span)
        if s.saved > 1 { t += " (-\(fmt(s.saved)))" }
        return t + "  →  " + s.end.short
    }
}

struct ListScreen: View {
    @EnvironmentObject var p: Planner
    @State private var addLane: LaneSel?
    @State private var sel: ItemSel?

    var body: some View {
        NavigationView {
            List {
                Section("시작 시각") {
                    DatePicker("기준", selection: $p.origin)
                }
                Section("장인 포션 (1시간, 모든 장인 10배)") {
                    ForEach($p.potions) { $x in
                        DatePicker("시작", selection: $x.start)
                    }
                    .onDelete { p.potions.remove(atOffsets: $0) }
                    Button("포션 추가 (기준 시각)") {
                        p.potions.append(Potion(start: p.origin))
                    }
                }
                ForEach(p.lanes.indices, id: \.self) { l in
                    Section("장인 \(l + 1)") {
                        ForEach(p.slots(l)) { s in
                            Button { sel = ItemSel(id: s.id) } label: { Row(s: s) }
                        }
                        Button("+ 건물 추가") { addLane = LaneSel(id: l) }
                    }
                }
            }
            .navigationTitle("플래너 테스트")
        }
        .sheet(item: $addLane) { CatalogSheet(lane: $0.id) }
        .sheet(item: $sel) { ItemSheet(id: $0.id) }
    }
}

struct CatalogSheet: View {
    @EnvironmentObject var p: Planner
    @Environment(\.dismiss) var dismiss
    let lane: Int

    var body: some View {
        NavigationView {
            List(Catalog.pets) { pet in
                NavigationLink(pet.name) { LevelList(lane: lane, pet: pet) }
            }
            .navigationTitle("장인 \(lane + 1) 추가")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }
}

struct LevelList: View {
    @EnvironmentObject var p: Planner
    let lane: Int
    let pet: Pet

    var body: some View {
        List {
            Section("눌러서 추가 · 현재 \(p.lanes[lane].count)개") {
                ForEach(pet.ups) { u in
                    Button { p.add(lane, pet, u) } label: {
                        HStack {
                            Text("Lvl \(u.level)")
                            Spacer()
                            Text("\(u.cost)  \(fmt(u.work))").foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(pet.name)
    }
}

struct ItemSheet: View {
    @EnvironmentObject var p: Planner
    @Environment(\.dismiss) var dismiss
    let id: UUID

    var body: some View {
        NavigationView {
            Form {
                if let f = p.find(id) {
                    let s = p.slots(f.0)[f.1]
                    let h = p.finish(s.start, s.item.work, helper: true, potions: p.potions)
                    let hSaved = s.item.work - h.0.timeIntervalSince(s.start)
                    Section {
                        Text(s.item.title).bold()
                        Text("\(fmt(s.span)) (-\(fmt(s.saved)))  →  \(s.end.short)")
                    }
                    Section("조수 (1시간, 이 건물만 10배)") {
                        Toggle("조수 사용", isOn: Binding(
                            get: { s.item.helper },
                            set: { _ in p.toggleHelper(id) }
                        ))
                        Text("사용 시: 절약 \(fmt(hSaved)), 낭비 \(fmt(h.1))")
                            .font(.caption)
                    }
                    Section("장인 포션") {
                        Button("이 건물 시작 시각에 포션 사용") {
                            p.potions.append(Potion(start: s.start))
                        }
                        Text("사용 시 전체 장인 합계 절약 약 \(fmt(p.potionGain(start: s.start)))")
                            .font(.caption)
                    }
                    Section("편집") {
                        Button("위로") { p.move(id, by: -1) }
                        Button("아래로") { p.move(id, by: 1) }
                        Menu("다른 장인으로 이동") {
                            ForEach(p.lanes.indices, id: \.self) { n in
                                Button("장인 \(n + 1)") { p.moveTo(id, lane: n) }
                            }
                        }
                        Button("삭제", role: .destructive) {
                            p.remove(id)
                            dismiss()
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}

struct TimelineScreen: View {
    @EnvironmentObject var p: Planner
    @State private var px = 2.0
    let rowH = 44.0
    let labelW = 36.0

    var body: some View {
        let all = p.lanes.indices.map { p.slots($0) }
        let hours = max(24.0, p.horizon().timeIntervalSince(p.origin) / 3600)
        let width = labelW + hours * px + 40
        let height = rowH * Double(p.lanes.count)
        NavigationView {
            VStack {
                Picker("확대", selection: $px) {
                    Text("1일").tag(12.0)
                    Text("7일").tag(2.0)
                    Text("30일").tag(0.5)
                    Text("90일").tag(0.2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                ScrollView([.horizontal, .vertical]) {
                    ZStack(alignment: .topLeading) {
                        ForEach(0..<(Int(hours / 24) + 1), id: \.self) { d in
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 1, height: height)
                                .offset(x: labelW + Double(d) * 24 * px)
                        }
                        ForEach(p.potions) { q in
                            Rectangle()
                                .fill(Color.cyan.opacity(0.25))
                                .frame(width: max(2, K.window / 3600 * px), height: height)
                                .offset(x: labelW + q.start.timeIntervalSince(p.origin) / 3600 * px)
                        }
                        ForEach(p.lanes.indices, id: \.self) { l in
                            Text("B\(l + 1)")
                                .font(.caption)
                                .frame(width: labelW, height: rowH)
                                .offset(y: Double(l) * rowH)
                            ForEach(all[l]) { s in
                                bar(s, l)
                            }
                        }
                    }
                    .frame(width: width, height: height + 20, alignment: .topLeading)
                }
            }
            .navigationTitle("타임라인")
        }
    }

    func bar(_ s: Slot, _ l: Int) -> some View {
        let x = labelW + s.start.timeIntervalSince(p.origin) / 3600 * px
        let w = max(2, s.span / 3600 * px)
        var c = Color.gray.opacity(0.5)
        if s.saved > 1 { c = Color.cyan.opacity(0.6) }
        if s.item.helper { c = Color.purple.opacity(0.6) }
        return RoundedRectangle(cornerRadius: 4)
            .fill(c)
            .frame(width: w, height: rowH - 6)
            .overlay(Text(s.item.title).font(.caption2).lineLimit(1).padding(2), alignment: .leading)
            .clipped()
            .offset(x: x, y: Double(l) * rowH + 3)
    }
}
