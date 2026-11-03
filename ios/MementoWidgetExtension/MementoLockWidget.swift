import SwiftUI
import WidgetKit

// MARK: - Shared Timeline Entry & Data Model

struct MementoGoalItem: Codable, Hashable {
    let title: String
    let ddayText: String
}

struct MementoWidgetEntry: TimelineEntry {
    let date: Date
    let lifePercent: Double
    let age: Int
    let livedDaysLabel: String // e.g., "D+11,496"
    let quote: String
    let goals: [MementoGoalItem]
    let opacity: Double
    let boxHex: UInt32
    let textHex: UInt32
    let accentHex: UInt32
}

// MARK: - Timeline Provider (Reads Shared AppGroup UserDefaults from Flutter)

struct MementoProvider: TimelineProvider {
    private let appGroupId = "group.com.mementolock.shared"

    func placeholder(in context: Context) -> MementoWidgetEntry {
        defaultEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (MementoWidgetEntry) -> Void) {
        completion(loadEntryFromDefaults())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MementoWidgetEntry>) -> Void) {
        let entry = loadEntryFromDefaults()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntryFromDefaults() -> MementoWidgetEntry {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            return defaultEntry()
        }
        let pct = defaults.object(forKey: "lifePercent") as? Double ?? 39.37
        let age = defaults.object(forKey: "age") as? Int ?? 31
        let lived = defaults.string(forKey: "livedLabel") ?? "D+11,496"
        let quote = defaults.string(forKey: "quote") ?? "기억하라, 너는 언젠가 죽는다. — Memento Mori"
        let opacity = defaults.object(forKey: "opacity") as? Double ?? 0.75
        let boxHex = UInt32(defaults.integer(forKey: "boxColor") != 0 ? defaults.integer(forKey: "boxColor") : 0x0A0A0A)
        let textHex = UInt32(defaults.integer(forKey: "textColor") != 0 ? defaults.integer(forKey: "textColor") : 0xFFFFFF)
        let accentHex = UInt32(defaults.integer(forKey: "accentColor") != 0 ? defaults.integer(forKey: "accentColor") : 0xD8C3A5)

        let g1Title = defaults.string(forKey: "goal1Title") ?? "나의 목표"
        let g1Dday = defaults.string(forKey: "goal1Dday") ?? "D-100"
        let g2Title = defaults.string(forKey: "goal2Title") ?? "버킷리스트"
        let g2Dday = defaults.string(forKey: "goal2Dday") ?? "D-365"

        return MementoWidgetEntry(
            date: Date(),
            lifePercent: pct,
            age: age,
            livedDaysLabel: lived,
            quote: quote,
            goals: [
                MementoGoalItem(title: g1Title, ddayText: g1Dday),
                MementoGoalItem(title: g2Title, ddayText: g2Dday),
            ],
            opacity: opacity,
            boxHex: boxHex,
            textHex: textHex,
            accentHex: accentHex
        )
    }

    private func defaultEntry() -> MementoWidgetEntry {
        MementoWidgetEntry(
            date: Date(),
            lifePercent: 39.37,
            age: 31,
            livedDaysLabel: "D+11,496",
            quote: "기억하라, 너는 언젠가 죽는다. — Memento Mori",
            goals: [
                MementoGoalItem(title: "바디프로필", ddayText: "D-42"),
                MementoGoalItem(title: "세계일주 출발", ddayText: "D-180"),
            ],
            opacity: 0.75,
            boxHex: 0x0A0A0A,
            textHex: 0xFFFFFF,
            accentHex: 0xD8C3A5
        )
    }
}

// MARK: - Color Helper

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - iOS Lock Screen & Home Screen Widget View

struct MementoWidgetEntryView: View {
    var entry: MementoProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            // iOS 잠금화면 직사각형 위젯 (인생 게이지 + LIFE D+ + D-Day 2개)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(String(format: "%.1f%%", entry.lifePercent))
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Text("LIFE \(entry.livedDaysLabel)")
                        .font(.system(size: 10, weight: .medium))
                        .opacity(0.85)
                }
                ProgressView(value: entry.lifePercent, total: 100.0)
                    .progressViewStyle(.linear)
                HStack(spacing: 8) {
                    if let g1 = entry.goals.first {
                        Text("\(g1.title) \(g1.ddayText)")
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }
                    if entry.goals.count > 1 {
                        Text("· \(entry.goals[1].title) \(entry.goals[1].ddayText)")
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }
                }
            }
        default:
            // iOS 홈화면 Medium 배너 위젯 (투명도 · 박스/텍스트/포인트 컬러 반영)
            let boxColor = Color(hex: entry.boxHex, alpha: entry.opacity)
            let textColor = Color(hex: entry.textHex)
            let accentColor = Color(hex: entry.accentHex)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("MEMENTO LOCK")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(accentColor)
                    Spacer()
                    Text("LIFE \(entry.livedDaysLabel) · \(entry.age)세/80세")
                        .font(.system(size: 10))
                        .foregroundColor(accentColor)
                }
                HStack(alignment: .center, spacing: 12) {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(String(format: "%.1f", entry.lifePercent))
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(textColor)
                        Text("%")
                            .font(.system(size: 12))
                            .foregroundColor(accentColor)
                    }
                    ForEach(entry.goals.prefix(2), id: \.self) { g in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(g.title)
                                .font(.system(size: 10))
                                .foregroundColor(textColor.opacity(0.65))
                                .lineLimit(1)
                            Text(g.ddayText)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(accentColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Text(entry.quote)
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(textColor.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(14)
            .background(boxColor)
        }
    }
}

@main
struct MementoLockWidgetBundle: Widget {
    let kind: String = "MementoLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MementoProvider()) { entry in
            MementoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Memento Lock")
        .description("80세 인생 게이지, LIFE D+ 카운터, 최대 2개의 D-Day와 오늘의 메멘토 모리 문장을 표시합니다.")
        .supportedFamilies([.accessoryRectangular, .systemMedium])
    }
}
