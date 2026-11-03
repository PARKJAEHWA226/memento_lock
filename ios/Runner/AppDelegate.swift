import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    syncFlutterPrefsToWidget()
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
          self?.syncFlutterPrefsToWidget()
          result(true)
        case "requestPinWidget":
          self?.syncFlutterPrefsToWidget()
          result(false)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  private func syncFlutterPrefsToWidget() {
    let std = UserDefaults.standard
    let shared = UserDefaults(suiteName: "group.com.mementolock.shared")

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

    var g1Title = "D-Day 1 미설정"
    var g1Dday = "—"
    var g1Prog = 0.0
    var g2Title = "D-Day 2 추가 가능"
    var g2Dday = "—"
    var g2Prog = 0.0

    if let rawGoals = std.stringArray(forKey: "flutter.goals") {
      var parsed: [(String, String, Double)] = []
      for item in rawGoals {
        if let d = item.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
           let title = obj["title"] as? String,
           let dateStr = obj["date"] as? String,
           let dt = sdf.date(from: String(dateStr.prefix(10))) {
          let diff = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: dt)).day ?? 0
          let dday = diff > 0 ? "D-\(diff)" : (diff == 0 ? "D-DAY" : "D+\(-diff)")
          let prog = diff <= 0 ? 100.0 : max(8.0, min(100.0, Double(365 - min(365, max(0, diff))) / 365.0 * 100.0))
          parsed.append((title, dday, prog))
        }
      }
      if parsed.count > 0 {
        g1Title = parsed[0].0
        g1Dday = parsed[0].1
        g1Prog = parsed[0].2
      }
      if parsed.count > 1 {
        g2Title = parsed[1].0
        g2Dday = parsed[1].1
        g2Prog = parsed[1].2
      }
    }

    let quote = std.string(forKey: "flutter.lastQuote") ?? "기억하라, 너는 언젠가 죽는다. — Memento Mori"

    for target in [std, shared].compactMap({ $0 }) {
      target.set(pct, forKey: "lifePercent")
      target.set(age, forKey: "age")
      target.set(livedLabel, forKey: "livedLabel")
      target.set(remDaysLabel, forKey: "remainingDaysLabel")
      target.set(remWeekendsLabel, forKey: "remainingWeekendsLabel")
      target.set(yearPct, forKey: "yearPercent")
      target.set(todayPct, forKey: "todayPercent")
      target.set(home4x1Mode, forKey: "home4x1Mode")
      target.set(quote, forKey: "quote")
      target.set(opacity, forKey: "opacity")
      target.set(boxColor, forKey: "boxColor")
      target.set(textColor, forKey: "textColor")
      target.set(accentColor, forKey: "accentColor")
      target.set(g1Title, forKey: "goal1Title")
      target.set(g1Dday, forKey: "goal1Dday")
      target.set(g1Prog, forKey: "goal1Progress")
      target.set(g2Title, forKey: "goal2Title")
      target.set(g2Dday, forKey: "goal2Dday")
      target.set(g2Prog, forKey: "goal2Progress")
    }

    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
    }
  }
}
