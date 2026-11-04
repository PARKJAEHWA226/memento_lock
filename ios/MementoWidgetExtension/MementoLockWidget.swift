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
    let livedDaysLabel: String
    let remainingDaysLabel: String
    let remainingWeekendsLabel: String
    let yearPercent: Double
    let todayPercent: Double
    let home4x1Mode: Int
    let quote: String
    let goals: [MementoGoalItem]
    let opacity: Double
    let boxHex: UInt32
    let textHex: UInt32
    let accentHex: UInt32
}

// MARK: - Timeline Provider (Shared Container JSON + AppGroup UserDefaults + UserDefaults.standard 3중 복합 로더)

struct MementoProvider: TimelineProvider {
    private let appGroupId = "group.com.mementolock.shared"

    func placeholder(in context: Context) -> MementoWidgetEntry {
        loadEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (MementoWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MementoWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> MementoWidgetEntry {
        // 1. 공유 memento_data.json 파일 확인
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
            let fileURL = containerURL.appendingPathComponent("memento_data.json")
            if let data = try? Data(contentsOf: fileURL),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return parseEntry(from: json)
            }
        }
        if let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = docDir.appendingPathComponent("memento_data.json")
            if let data = try? Data(contentsOf: fileURL),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return parseEntry(from: json)
            }
        }

        // 2. AppGroup UserDefaults 확인
        if let shared = UserDefaults(suiteName: appGroupId),
           let pct = shared.object(forKey: "lifePercent") as? Double {
            return parseEntryFromDefaults(shared, defaultPct: pct)
        }

        // 3. UserDefaults.standard 확인
        let std = UserDefaults.standard
        if let pct = std.object(forKey: "lifePercent") as? Double {
            return parseEntryFromDefaults(std, defaultPct: pct)
        }

        // 4. 기본 폴백
        return defaultEntry()
    }

    private func parseEntry(from d: [String: Any]) -> MementoWidgetEntry {
        let pct = (d["lifePercent"] as? Double) ?? 49.6
        let age = (d["age"] as? Int) ?? 39
        let lived = (d["livedLabel"] as? String) ?? "D+14,501"
        let remDays = (d["remainingDaysLabel"] as? String) ?? "14,719일"
        let remWeekends = (d["remainingWeekendsLabel"] as? String) ?? "2,102회"
        let yearPct = (d["yearPercent"] as? Double) ?? 84.1
        let todayPct = (d["todayPercent"] as? Double) ?? 66.0
        let homeMode = (d["home4x1Mode"] as? Int) ?? 0
        let quote = (d["quote"] as? String) ?? "기억하라, 너는 언젠가 죽는다. — Memento Mori"
        let opacity = (d["opacity"] as? Double) ?? 0.75
        let boxHex = UInt32((d["boxColor"] as? Int) ?? 0x0A0A0A)
        let textHex = UInt32((d["textColor"] as? Int) ?? 0xFFFFFF)
        let accentHex = UInt32((d["accentColor"] as? Int) ?? 0xD8C3A5)

        var goals: [MementoGoalItem] = []
        if let rawGoals = d["goals"] as? [[String: Any]] {
            for g in rawGoals {
                goals.append(MementoGoalItem(
                    title: g["title"] as? String ?? "나의 목표",
                    ddayText: g["dday"] as? String ?? "D-DAY",
                    progressPercent: g["progress"] as? Double ?? 50.0
                ))
            }
        }
        if goals.isEmpty {
            goals.append(MementoGoalItem(title: "나의 목표", ddayText: "D-100", progressPercent: 72.0))
            goals.append(MementoGoalItem(title: "버킷리스트", ddayText: "D-365", progressPercent: 25.0))
        }

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
            goals: goals,
            opacity: opacity,
            boxHex: boxHex,
            textHex: textHex,
            accentHex: accentHex
        )
    }

    private func parseEntryFromDefaults(_ defaults: UserDefaults, defaultPct: Double) -> MementoWidgetEntry {
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
            lifePercent: defaultPct,
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
            lifePercent: 49.6,
            age: 39,
            livedDaysLabel: "D+14,501",
            remainingDaysLabel: "14,719일",
            remainingWeekendsLabel: "2,102회",
            yearPercent: 84.1,
            todayPercent: 66.0,
            home4x1Mode: 0,
            quote: "기억하라, 너는 언젠가 죽는다. — Memento Mori",
            goals: [
                MementoGoalItem(title: "나의 목표", ddayText: "D-100", progressPercent: 72.0),
                MementoGoalItem(title: "버킷리스트", ddayText: "D-365", progressPercent: 25.0),
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

// MARK: - 1. 메인 잠금화면 직사각형 위젯 (인생 게이지 + D-Day · 2칸 안에서 절대 말줄임 없이 시원하게 꽉 차도록 최적화)

@available(iOS 16.0, *)
struct MementoLockGaugeView: View {
    let entry: MementoWidgetEntry

    var body: some View {
        let textColor = Color(hex: entry.textHex)
        let accentColor = Color(hex: entry.accentHex)
        let g1 = entry.goals.first

        VStack(alignment: .leading, spacing: 3) {
            // 1행: 대형 퍼센트 (17pt 볼드) + LIFE D+ 카운터
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.1f%%", entry.lifePercent))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(textColor)
                Spacer(minLength: 4)
                Text("LIFE \(entry.livedDaysLabel)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(accentColor)
                    .lineLimit(1)
            }

            // 2행: 게이지 바 (높이 4pt 꽉 차게)
            ProgressView(value: entry.lifePercent, total: 100.0)
                .progressViewStyle(.linear)
                .tint(accentColor)

            // 3행: 대표 D-Day (말줄임표 없이 크고 선명하게 1줄 노출)
            if let g = g1 {
                HStack(spacing: 4) {
                    Text(g.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(textColor.opacity(0.9))
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Text(g.ddayText)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(accentColor)
                        .lineLimit(1)
                }
            } else {
                Text(entry.quote)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(textColor.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - 2. 잠금화면 명언 전용 직사각형 위젯 (시계 아래 오른쪽에 나란히 두면 화면 전체 가로가 100% 꽉 채워짐!)

@available(iOS 16.0, *)
struct MementoLockQuoteView: View {
    let entry: MementoWidgetEntry

    var body: some View {
        let textColor = Color(hex: entry.textHex)
        let accentColor = Color(hex: entry.accentHex)

        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("MEMENTO MORI")
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(1)
                    .foregroundColor(accentColor)
                Spacer()
                Text("\(entry.age)/80세")
                    .font(.system(size: 9.5))
                    .foregroundColor(textColor.opacity(0.7))
            }
            Text(entry.quote)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(textColor)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - 3. 시계 윗줄 인라인 위젯 (accessoryInline)

@available(iOS 16.0, *)
struct MementoLockInlineView: View {
    let entry: MementoWidgetEntry

    var body: some View {
        let g1 = entry.goals.first
        if let g = g1 {
            Text("\(String(format: "%.1f%%", entry.lifePercent)) · \(g.title) \(g.ddayText)")
        } else {
            Text("\(String(format: "%.1f%%", entry.lifePercent)) · LIFE \(entry.livedDaysLabel)")
        }
    }
}

// MARK: - 4. 홈화면 Medium 배너 위젯 (systemMedium · 3가지 모드)

@available(iOS 16.0, *)
struct MementoHomeMediumView: View {
    let entry: MementoWidgetEntry

    var body: some View {
        let boxColor = Color(hex: entry.boxHex, alpha: entry.opacity)
        let textColor = Color(hex: entry.textHex)
        let accentColor = Color(hex: entry.accentHex)
        let g1 = entry.goals.first

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

            // 가운데: 선택한 모드
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
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("남은 주말")
                                .font(.system(size: 9))
                                .foregroundColor(textColor.opacity(0.6))
                            Text(entry.remainingWeekendsLabel)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(accentColor)
                                .lineLimit(1)
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
                    Text("D-Day 달성 프로그레스")
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

// MARK: - iOS 17 containerBackground 확장 헬퍼

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

// MARK: - 위젯 1: [메멘토 락: 인생 게이지 & D-Day] (잠금화면 직사각형 & 시계 위 인라인 & 홈화면 Medium 지원)

struct MementoLockWidget: Widget {
    let kind: String = "MementoLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MementoProvider()) { entry in
            if #available(iOS 16.0, *) {
                MementoLockWidgetDispatcher(entry: entry)
            } else {
                Text(String(format: "%.1f%%", entry.lifePercent))
            }
        }
        .configurationDisplayName("메멘토 락 (인생 게이지 & D-Day)")
        .description("80세 인생 퍼센트, LIFE D+, 게이지 바 및 대표 D-Day를 시원하게 표시합니다. (잠금화면 왼쪽 배치 추천)")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .systemMedium])
    }
}

@available(iOS 16.0, *)
struct MementoLockWidgetDispatcher: View {
    let entry: MementoWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryInline:
            MementoLockInlineView(entry: entry)
        case .accessoryRectangular:
            MementoLockGaugeView(entry: entry)
                .mementoWidgetBackground(Color.clear)
        default:
            MementoHomeMediumView(entry: entry)
                .mementoWidgetBackground(Color(hex: entry.boxHex, alpha: entry.opacity))
        }
    }
}

// MARK: - 위젯 2: [메멘토 락: 메멘토 모리 명언] (잠금화면 오른쪽 배치 시 시계 아래 전체 폭 100% 완성!)

struct MementoQuoteWidget: Widget {
    let kind: String = "MementoQuoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MementoProvider()) { entry in
            if #available(iOS 16.0, *) {
                MementoLockQuoteView(entry: entry)
                    .mementoWidgetBackground(Color.clear)
            } else {
                Text(entry.quote)
            }
        }
        .configurationDisplayName("메멘토 락 (오늘의 명언)")
        .description("오늘의 메멘토 모리 명언을 크게 표시합니다. 잠금화면 오른쪽 2칸에 배치하면 시계 아래가 100% 꽉 찹니다!")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - 위젯 번들 (아이폰 위젯 목록에서 2가지 잠금화면 위젯 + 홈화면 위젯 선택 가능)

@main
struct MementoLockWidgetBundle: WidgetBundle {
    var body: some Widget {
        MementoLockWidget()
        MementoQuoteWidget()
    }
}
