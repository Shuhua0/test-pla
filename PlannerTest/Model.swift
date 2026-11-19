import Foundation

struct Upgrade: Identifiable {
    let id = UUID()
    let level: Int
    let cost: String
    let work: Double
}

struct Pet: Identifiable {
    let id = UUID()
    let name: String
    let ups: [Upgrade]
}

enum Catalog {
    static func secs(_ s: String) -> Double {
        var total = 0.0
        var num = ""
        for c in s {
            if c.isNumber {
                num.append(c)
            } else {
                let n = Double(num) ?? 0
                num = ""
                if c == "d" { total += n * 86400 }
                if c == "h" { total += n * 3600 }
                if c == "m" { total += n * 60 }
            }
        }
        return total
    }

    static func make(_ name: String, _ rows: String) -> Pet {
        var ups: [Upgrade] = []
        let parts = rows.split(separator: ",")
        for (i, r) in parts.enumerated() {
            let p = r.split(separator: " ")
            ups.append(Upgrade(level: i + 2, cost: String(p[0]), work: secs(String(p[1]))))
        }
        return Pet(name: name, ups: ups)
    }

    static func lin(_ start: Int, _ step: Int, _ n: Int, _ d: String) -> String {
        var a: [String] = []
        for i in 0..<n { a.append("\(start + i * step)K \(d)") }
        return a.joined(separator: ",")
    }

    static let pets: [Pet] = [
        make("L.A.S.S.I", "20K 1d,30K 1d12h,40K 2d,50K 2d12h,60K 3d,70K 3d12h,80K 4d,90K 4d12h,100K 5d,110K 5d12h,120K 6d,130K 6d12h,140K 7d,150K 7d12h"),
        make("Electro Owl", "30K 1d12h,45K 2d,60K 3d,75K 4d,90K 4d12h,105K 5d,120K 5d12h,135K 6d,150K 6d12h,165K 7d,180K 7d12h,195K 7d12h,210K 7d12h,225K 7d12h"),
        make("Mighty Yak", "40K 1d,50K 1d12h,60K 2d,70K 2d12h,80K 3d,90K 3d12h,100K 4d,110K 4d12h,120K 5d,130K 5d12h,140K 6d,150K 6d12h,160K 7d,170K 7d12h"),
        make("Unicorn", "50K 1d12h,65K 2d,80K 3d,95K 4d,110K 4d12h,125K 5d,140K 5d12h,155K 6d,170K 6d12h,200K 7d,230K 7d12h,260K 7d12h,290K 7d12h,320K 7d12h"),
        make("Frosty", "70K 1d12h,85K 2d,100K 3d,115K 4d,130K 4d12h,145K 5d,160K 5d12h,170K 6d,180K 6d12h,200K 7d,230K 7d12h,260K 7d12h,290K 7d12h,320K 7d12h"),
        make("Diggy", "90K 1d12h,105K 2d,120K 3d,130K 4d,140K 4d12h,150K 5d,160K 5d12h,170K 6d,180K 6d12h,220K 7d,250K 7d12h,280K 8d,310K 8d,350K 8d"),
        make("Poison Lizard", "60K 1d,75K 1d12h,90K 2d,100K 2d12h,110K 3d,120K 3d12h,130K 4d,140K 4d12h,150K 5d,180K 6d,200K 7d,220K 7d12h,240K 7d12h,260K 7d12h"),
        make("Phoenix", "80K 1d12h,95K 2d,110K 3d,125K 4d,140K 4d12h,155K 5d,170K 5d12h,180K 6d,190K 6d12h"),
        make("Spirit Fox", "150K 3d,160K 4d,170K 5d,180K 5d12h,190K 6d,200K 6d12h,210K 7d,220K 7d12h,230K 7d12h"),
        make("Angry Jelly", "150K 3d,160K 4d,170K 5d,180K 6d,190K 7d,200K 7d,210K 7d,220K 7d12h,230K 7d12h,260K 7d12h,290K 8d,320K 8d,350K 8d,380K 8d"),
        make("Sneezy", lin(200, 20, 9, "7d12h")),
        make("Greedy Raven", lin(260, 20, 9, "8d")),
    ]
}

enum K {
    static let boost = 10.0
    static let window = 3600.0
}

struct Item: Identifiable {
    var id = UUID()
    let title: String
    let cost: String
    let work: Double
    var helper = false
}

struct Potion: Identifiable {
    var id = UUID()
    var start: Date
}

struct Slot: Identifiable {
    let id: UUID
    let item: Item
    let start: Date
    let end: Date
    let waste: Double
    var span: Double { end.timeIntervalSince(start) }
    var saved: Double { item.work - span }
}

func fmt(_ s: Double) -> String {
    let t = Int(max(0, s).rounded())
    let d = t / 86400
    let h = (t % 86400) / 3600
    let m = (t % 3600) / 60
    if d > 0 { return "\(d)d \(h)h" }
    if h > 0 { return "\(h)h \(m)m" }
    return "\(m)m"
}

extension Date {
    var short: String {
        let f = DateFormatter()
        f.dateFormat = "M/d HH:mm"
        return f.string(from: self)
    }
}

final class Planner: ObservableObject {
    @Published var origin = Date()
    @Published var lanes: [[Item]] = Array(repeating: [], count: 6)
    @Published var potions: [Potion] = []

    // 작업량(work)을 구간별 배속으로 깎아서 종료 시각을 계산.
    // 포션과 조수가 겹치면 10 x 10 = 100배 (곱연산). 포션끼리는 겹쳐도 10배.
    func finish(_ start: Date, _ work: Double, helper: Bool, potions ps: [Potion]) -> (Date, Double) {
        let s0 = start.timeIntervalSince1970
        let hEnd = s0 + K.window
        var cur = s0
        var rem = work
        let pw = ps.map { $0.start.timeIntervalSince1970 }
        var bounds: [Double] = []
        for p in pw {
            bounds.append(p)
            bounds.append(p + K.window)
        }
        if helper { bounds.append(hEnd) }
        bounds.sort()
        while true {
            var potionOn = false
            for p in pw where cur >= p && cur < p + K.window { potionOn = true }
            var rate = 1.0
            if potionOn { rate *= K.boost }
            if helper && cur < hEnd { rate *= K.boost }
            if let nb = bounds.first(where: { $0 > cur }) {
                let can = (nb - cur) * rate
                if can >= rem {
                    cur += rem / rate
                    break
                }
                rem -= can
                cur = nb
            } else {
                cur += rem / rate
                break
            }
        }
        var waste = 0.0
        if helper {
            let used = max(0, min(cur, hEnd) - s0)
            waste = K.window - used
        }
        return (Date(timeIntervalSince1970: cur), waste)
    }

    func slots(_ lane: Int, potions ps: [Potion]? = nil) -> [Slot] {
        let use = ps ?? potions
        var t = origin
        var out: [Slot] = []
        for it in lanes[lane] {
            let r = finish(t, it.work, helper: it.helper, potions: use)
            out.append(Slot(id: it.id, item: it, start: t, end: r.0, waste: r.1))
            t = r.0
        }
        return out
    }

    func potionGain(start: Date) -> Double {
        let ps = potions + [Potion(start: start)]
        var total = 0.0
        for l in lanes.indices {
            if let a = slots(l).last?.end, let b = slots(l, potions: ps).last?.end {
                total += a.timeIntervalSince(b)
            }
        }
        return total
    }

    func horizon() -> Date {
        var e = origin
        for l in lanes.indices {
            if let x = slots(l).last?.end, x > e { e = x }
        }
        for q in potions {
            let x = q.start.addingTimeInterval(K.window)
            if x > e { e = x }
        }
        return e
    }

    func add(_ lane: Int, _ pet: Pet, _ u: Upgrade) {
        lanes[lane].append(Item(title: "\(pet.name) Lvl \(u.level)", cost: u.cost, work: u.work))
    }

    func find(_ id: UUID) -> (Int, Int)? {
        for l in lanes.indices {
            if let i = lanes[l].firstIndex(where: { $0.id == id }) { return (l, i) }
        }
        return nil
    }

    func remove(_ id: UUID) {
        if let f = find(id) { lanes[f.0].remove(at: f.1) }
    }

    func move(_ id: UUID, by d: Int) {
        guard let f = find(id) else { return }
        let j = f.1 + d
        if lanes[f.0].indices.contains(j) { lanes[f.0].swapAt(f.1, j) }
    }

    func moveTo(_ id: UUID, lane: Int) {
        guard let f = find(id), f.0 != lane else { return }
        let it = lanes[f.0].remove(at: f.1)
        lanes[lane].append(it)
    }

    func toggleHelper(_ id: UUID) {
        if let f = find(id) { lanes[f.0][f.1].helper.toggle() }
    }
}
