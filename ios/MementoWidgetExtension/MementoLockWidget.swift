import SwiftUI
import WidgetKit

// MARK: - Shared Timeline Entry & Data Model

struct MementoGoalItem: Codable, Hashable {
    let title: String
    let ddayText: String
    let progressPercent: Double
}

struct MementoWidgetEntry: TimelineEntry {
    let date: Date
    let lifePercent: Double
    let age: Int
    let livedDaysLabel: String // e.g., "D+11,496"
    let remainingDaysLabel: String // e.g., "17,724일"
    let remainingWeekendsLabel: String // e.g., "2,532회"
    let yearPercent: Double
    let todayPercent: Double
    let home4x1Mode: Int // 0: 올해·오늘 게이지, 1: 남은 날·주말, 2: D-Day 프로그레스
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
        let pct = defaults.object(forKey: "lifePercent") as? Double ?? 49.0
        let age = defaults.object(forKey: "age") as? Int ?? 39
        let lived = defaults.string(forKey: "livedLabel") ?? "D+14,501"
        let remDays = defaults.string(forKey: "remainingDaysLabel") ?? "14,719일"
        let remWeekends = defaults.string(forKey: "remainingWeekendsLabel") ?? "2,102회"
        let yearPct = defaults.object(forKey: "yearPercent") as? Double ?? 84.1
        let todayPct = defaults.object(forKey: "todayPercent") as? Double ?? 66.0
        let homeMode = defaults.object(forKey: "home4x1Mode") as? Int ?? 0
        let quote = defaults.string(forKey: "quote") ?? "기억하라, 너는 언젠가 죽는다. — Memento Mori"
        let opacity = defaults.object(forKey: "opacity") as? Double ?? 0.75
        let boxHex = UInt32(defaults.integer(forKey: "boxColor") != 0 ? defaults.integer(forKey: "boxColor") : 0x0A0A0A)
        let textHex = UInt32(defaults.integer(forKey: "textColor") != 0 ? defaults.integer(forKey: "textColor") : 0xFFFFFF)
        let accentHex = UInt32(defaults.integer(forKey: "accentColor") != 0 ? defaults.integer(forKey: "accentColor") : 0xD8C3A5)

        let g1Title = defaults.string(forKey: "goal1Title") ?? "나의 목표"
        let g1Dday = defaults.string(forKey: "goal1Dday") ?? "D-100"
        let g1Prog = defaults.object(forKey: "goal1Progress") as? Double ?? 72.0
        let g2Title = defaults.string(forKey: "goal2Title") ?? "버킷리스트"
        let g2Dday = defaults.string(forKey: "goal2Dday") ?? "D-365"
        let g2Prog = defaults.object(forKey: "goal2Progress") as? Double ?? 25.0

        return MementoWidgetEntry(
            date: Date(),
            lifePercent: pct,
            age: age,
            livedDaysLabel: lived,
            remainingDaysLabel: remDays,
            remainingWeekendsLabel: remWeekends,
            yearPercent: yearPct,
            todayPercent: todayPct,
            home4x1Mode: homeMode,
            quote: quote,
            goals: [
                MementoGoalItem(title: g1Title, ddayText: g1Dday, progressPercent: g1Prog),
                MementoGoalItem(title: g2Title, ddayText: g2Dday, progressPercent: g2Prog),
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
            lifePercent: 49.0,
            age: 39,
            livedDaysLabel: "D+14,501",
            remainingDaysLabel: "14,719일",
            remainingWeekendsLabel: "2,102회",
            yearPercent: 84.1,
            todayPercent: 66.0,
            home4x1Mode: 0,
            quote: "기억하라, 너는 언젠가 죽는다. — Memento Mori",
            goals: [
                MementoGoalItem(title: "바디프로필", ddayText: "D-42", progressPercent: 88.0),
                MementoGoalItem(title: "세계일주 출발", ddayText: "D-180", progressPercent: 50.0),
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

@available(iOS 16.0, *)
struct MementoWidgetEntryView: View {
    var entry: MementoProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            // 1) iOS 잠금화면 직사각형 위젯 (전체 폭 확장 · 변경한 텍스트/포인트 컬러 반영)
            let textColor = Color(hex: entry.textHex)
            let accentColor = Color(hex: entry.accentHex)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(String(format: "%.1f%%", entry.lifePercent))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(textColor)
                    Spacer(minLength: 4)
                    Text("LIFE \(entry.livedDaysLabel)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(accentColor)
                }
                .frame(maxWidth: .infinity)
                ProgressView(value: entry.lifePercent, total: 100.0)
                    .progressViewStyle(.linear)
                    .tint(accentColor)
                    .frame(maxWidth: .infinity)
                HStack(spacing: 6) {
                    if let g1 = entry.goals.first {
                        Text("\(g1.title) \(g1.ddayText)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(accentColor)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 2)
                    if entry.goals.count > 1 {
                        Text("· \(entry.goals[1].title) \(entry.goals[1].ddayText)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(textColor)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(entry.quote)
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        default:
            // 2) iOS 홈화면 Medium 배너 위젯 (명언 미노출 · 3가지 타임/목표 지표 모드 지원)
            let boxColor = Color(hex: entry.boxHex, alpha: entry.opacity)
            let textColor = Color(hex: entry.textHex)
            let accentColor = Color(hex: entry.accentHex)
            let g1 = entry.goals.first
            let g2 = entry.goals.count > 1 ? entry.goals[1] : nil

            HStack(alignment: .center, spacing: 10) {
                // 왼쪽: 인생 게이지 수치 + 바 + LIFE D+
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .lastTextBaseline, spacing: 1) {
                        Text(String(format: "%.1f", entry.lifePercent))
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(textColor)
                        Text("%")
                            .font(.system(size: 10))
                            .foregroundColor(accentColor)
                    }
                    ProgressView(value: entry.lifePercent, total: 100.0)
                        .tint(accentColor)
                    Text("LIFE \(entry.livedDaysLabel)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(accentColor)
                        .lineLimit(1)
                }
                .frame(width: 82, alignment: .leading)

                Rectangle()
                    .fill(textColor.opacity(0.18))
                    .frame(width: 1, height: 46)

                // 가운데: 선택한 모드 (0: 올해·오늘 게이지, 1: 남은 날·주말, 2: D-Day 프로그레스)
                VStack(alignment: .leading, spacing: 4) {
                    if entry.home4x1Mode == 1 {
                        Text("REMAINING (80세)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(textColor.opacity(0.6))
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("남은 날")
                                    .font(.system(size: 9))
                                    .foregroundColor(textColor.opacity(0.6))
                                Text(entry.remainingDaysLabel)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(textColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text("남은 주말")
                                    .font(.system(size: 9))
                                    .foregroundColor(textColor.opacity(0.6))
                                Text(entry.remainingWeekendsLabel)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(accentColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                        }
                    } else if entry.home4x1Mode == 2 {
                        HStack {
                            Text("TARGET · \(g1?.title ?? "목표")")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(textColor)
                                .lineLimit(1)
                            Spacer()
                            Text(String(format: "%.0f%%", g1?.progressPercent ?? 0))
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(accentColor)
                        }
                        ProgressView(value: g1?.progressPercent ?? 0, total: 100.0)
                            .tint(accentColor)
                        Text(g2 != nil ? "NEXT · \(g2!.title) (\(g2!.ddayText))" : "D-Day 달성 프로그레스")
                            .font(.system(size: 9))
                            .foregroundColor(textColor.opacity(0.65))
                            .lineLimit(1)
                    } else {
                        HStack {
                            Text("YEAR")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(textColor.opacity(0.6))
                            Spacer()
                            Text(String(format: "%.1f%%", entry.yearPercent))
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(textColor)
                        }
                        ProgressView(value: entry.yearPercent, total: 100.0)
                            .tint(accentColor)
                        HStack {
                            Text("TODAY")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(textColor.opacity(0.6))
                            Spacer()
                            Text(String(format: "%.1f%%", entry.todayPercent))
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(accentColor)
                        }
                        ProgressView(value: entry.todayPercent, total: 100.0)
                            .tint(textColor.opacity(0.85))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 오른쪽: 대표 D-Day 강조
                VStack(alignment: .trailing, spacing: 2) {
                    Text(g1?.title ?? "목표 미설정")
                        .font(.system(size: 9))
                        .foregroundColor(textColor.opacity(0.65))
                        .lineLimit(1)
                    Text(g1?.ddayText ?? "D-DAY")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(width: 64, alignment: .trailing)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(boxColor)
        }
    }
}

extension View {
    @ViewBuilder
    func mementoWidgetBackground(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(color, for: .widget)
        } else {
            self.background(color)
        }
    }
}

@main
@available(iOS 16.0, *)
struct MementoLockWidgetBundle: Widget {
    let kind: String = "MementoLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MementoProvider()) { entry in
            let boxColor = Color(hex: entry.boxHex, alpha: entry.opacity)
            MementoWidgetEntryView(entry: entry)
                .mementoWidgetBackground(boxColor)
        }
        .configurationDisplayName("Memento Lock")
        .description("잠금화면 위젯(인생 게이지 + D-Day 2개 + 명언) 및 홈화면 Medium 위젯(인생 게이지 + 3가지 타임/목표 지표 + D-Day)을 표시합니다.")
        .supportedFamilies([.accessoryRectangular, .systemMedium])
    }
}
