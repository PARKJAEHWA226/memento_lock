import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let appGroupId = "group.com.mementolock.shared"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    syncFromFlutterPrefs()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MementoWidgetChannel") {
      let channel = FlutterMethodChannel(
        name: "com.mementolock.memento_lock/widgets",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "updateWidgets":
          if let args = call.arguments as? [String: Any] {
            self?.savePayloadToWidgetStorage(args)
          } else {
            self?.syncFromFlutterPrefs()
          }
          result(true)
        case "requestPinWidget":
          result(false)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  private func savePayloadToWidgetStorage(_ dict: [String: Any]) {
    let std = UserDefaults.standard
    let shared = UserDefaults(suiteName: appGroupId)

    for target in [std, shared].compactMap({ $0 }) {
      if let pct = dict["lifePercent"] as? Double { target.set(pct, forKey: "lifePercent") }
      if let age = dict["age"] as? Int { target.set(age, forKey: "age") }
      if let lived = dict["livedLabel"] as? String { target.set(lived, forKey: "livedLabel") }
      if let remDays = dict["remainingDaysLabel"] as? String { target.set(remDays, forKey: "remainingDaysLabel") }
      if let remWeekends = dict["remainingWeekendsLabel"] as? String { target.set(remWeekends, forKey: "remainingWeekendsLabel") }
      if let yearPct = dict["yearPercent"] as? Double { target.set(yearPct, forKey: "yearPercent") }
      if let todayPct = dict["todayPercent"] as? Double { target.set(todayPct, forKey: "todayPercent") }
      if let homeMode = dict["home4x1Mode"] as? Int { target.set(homeMode, forKey: "home4x1Mode") }
      if let quote = dict["quote"] as? String { target.set(quote, forKey: "quote") }
      if let opacity = dict["opacity"] as? Double { target.set(opacity, forKey: "opacity") }
      if let boxColor = dict["boxColor"] as? Int { target.set(boxColor, forKey: "boxColor") }
      if let textColor = dict["textColor"] as? Int { target.set(textColor, forKey: "textColor") }
      if let accentColor = dict["accentColor"] as? Int { target.set(accentColor, forKey: "accentColor") }

      if let goals = dict["goals"] as? [[String: Any]] {
        if goals.count > 0 {
          target.set(goals[0]["title"] as? String ?? "나의 목표", forKey: "goal1Title")
          target.set(goals[0]["dday"] as? String ?? "D-DAY", forKey: "goal1Dday")
          target.set(goals[0]["progress"] as? Double ?? 50.0, forKey: "goal1Progress")
        }
        if goals.count > 1 {
          target.set(goals[1]["title"] as? String ?? "버킷리스트", forKey: "goal2Title")
          target.set(goals[1]["dday"] as? String ?? "D-DAY", forKey: "goal2Dday")
          target.set(goals[1]["progress"] as? Double ?? 50.0, forKey: "goal2Progress")
        }
      }
      target.synchronize()
    }

    // 파일 기반 공유 (AppGroup 또는 Shared Container에 memento_data.json 기록)
    if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]) {
      if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
        let fileURL = containerURL.appendingPathComponent("memento_data.json")
        try? jsonData.write(to: fileURL)
      }
      if let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let localURL = docDir.appendingPathComponent("memento_data.json")
        try? jsonData.write(to: localURL)
      }
    }

    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
    }
  }

  private func syncFromFlutterPrefs() {
    let std = UserDefaults.standard
    let birthStr = std.string(forKey: "flutter.birth") ?? "1995-05-15"
    let sdf = DateFormatter()
    sdf.dateFormat = "yyyy-MM-dd"
    sdf.locale = Locale(identifier: "en_US_POSIX")
    let birthDate = sdf.date(from: String(birthStr.prefix(10))) ?? Date(timeIntervalSince1970: 800496000)

    let now = Date()
    let cal = Calendar.current
    let endDate = cal.date(byAdding: .year, value: 80, to: birthDate) ?? now
    let totalDays = max(1, cal.dateComponents([.day], from: birthDate, to: endDate).day ?? 29220)
    let livedDays = max(0, cal.dateComponents([.day], from: birthDate, to: now).day ?? 11496)
    let remLifeDays = max(0, cal.dateComponents([.day], from: now, to: endDate).day ?? 17724)
    let pct = min(100.0, max(0.0, Double(livedDays) / Double(totalDays) * 100.0))
    let age = Int(Double(livedDays) / 365.25)

    let nf = NumberFormatter()
    nf.numberStyle = .decimal
    let livedLabel = "D+\(nf.string(from: NSNumber(value: livedDays)) ?? "\(livedDays)")"
    let remDaysLabel = "\(nf.string(from: NSNumber(value: remLifeDays)) ?? "\(remLifeDays)")일"
    let remWeekendsLabel = "\(nf.string(from: NSNumber(value: remLifeDays / 7)) ?? "\(remLifeDays / 7)")회"

    let year = cal.component(.year, from: now)
    let startYear = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
    let endYear = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? now
    let yearPct = min(100.0, max(0.0, now.timeIntervalSince(startYear) / max(1.0, endYear.timeIntervalSince(startYear)) * 100.0))

    let comps = cal.dateComponents([.hour, .minute, .second], from: now)
    let secToday = Double((comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60 + (comps.second ?? 0))
    let todayPct = min(100.0, max(0.0, secToday / 86400.0 * 100.0))

    var opacity = 0.75
    var boxColor = 0x0A0A0A
    var textColor = 0xFFFFFF
    var accentColor = 0xD8C3A5
    var home4x1Mode = 0

    if let rawStyle = std.string(forKey: "flutter.widgetStyle"),
       let data = rawStyle.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      opacity = (json["opacity"] as? Double) ?? 0.75
      if let b = json["boxColor"] as? Int { boxColor = b & 0xFFFFFF }
      if let t = json["textColor"] as? Int { textColor = t & 0xFFFFFF }
      if let a = json["accentColor"] as? Int { accentColor = a & 0xFFFFFF }
      home4x1Mode = (json["home4x1Mode"] as? Int) ?? 0
    }

    var goalsPayload: [[String: Any]] = []
    if let rawGoals = std.stringArray(forKey: "flutter.goals") {
      for item in rawGoals {
        if let d = item.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
           let title = obj["title"] as? String,
           let dateStr = obj["date"] as? String,
           let dt = sdf.date(from: String(dateStr.prefix(10))) {
          let diff = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: dt)).day ?? 0
          let dday = diff > 0 ? "D-\(diff)" : (diff == 0 ? "D-DAY" : "D+\(-diff)")
          let prog = diff <= 0 ? 100.0 : max(8.0, min(100.0, Double(365 - min(365, max(0, diff))) / 365.0 * 100.0))
          goalsPayload.append(["title": title, "dday": dday, "progress": prog])
        }
      }
    }

    let quote = std.string(forKey: "flutter.lastQuote") ?? "기억하라, 너는 언젠가 죽는다. — Memento Mori"

    let dict: [String: Any] = [
      "lifePercent": pct,
      "age": age,
      "livedLabel": livedLabel,
      "remainingDaysLabel": remDaysLabel,
      "remainingWeekendsLabel": remWeekendsLabel,
      "yearPercent": yearPct,
      "todayPercent": todayPct,
      "home4x1Mode": home4x1Mode,
      "quote": quote,
      "opacity": opacity,
      "boxColor": boxColor,
      "textColor": textColor,
      "accentColor": accentColor,
      "goals": goalsPayload
    ]
    savePayloadToWidgetStorage(dict)
  }
}
