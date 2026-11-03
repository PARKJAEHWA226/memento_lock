import 'dart:convert';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MementoLockApp());

/// 인생 게이지 기준 수명 (년)
const int kLifeExpectancyYears = 80;

/// 시그니처 포인트 컬러: 샌드베이지 (Sand Beige)
const Color kSandBeige = Color(0xFFD8C3A5);
const Color kSandBeigeDim = Color(0x66D8C3A5);
const Color kCardBg = Color(0xFF0D0D0D);

/// 명언 노출 방식
enum QuoteMode {
  daily, // 하루에 한 번 고정 (오늘의 문장)
  everyTime, // 화면을 열거나 볼 때마다 랜덤
}

/// 위젯 스타일 설정 (투명도 + 박스 컬러 + 텍스트 컬러 + 게이지 컬러 + 4x1 가운데 표시 모드 + 사용자 추가 컬러 팔레트)
class WidgetStyle {
  final double opacity; // 0.0 (완전 투명) ~ 1.0 (불투명)
  final int boxColorValue;
  final int textColorValue;
  final int accentColorValue;
  final int wallpaperPreset; // 0: 노을 그라데이션(기본), 1: 밝은 모래, 2: 어두운 밤
  final int home4x1Mode; // 0: 올해/오늘 진행률 듀얼 게이지, 1: 80세까지 남은 일수·주말 카운트다운, 2: D-Day 목표 프로그레스 & 2개 목표 요약
  final List<int> customBoxColors;
  final List<int> customTextColors;
  final List<int> customAccentColors;

  const WidgetStyle({
    this.opacity = 0.75,
    this.boxColorValue = 0xFF0A0A0A,
    this.textColorValue = 0xFFFFFFFF,
    this.accentColorValue = 0xFFD8C3A5,
    this.wallpaperPreset = 0,
    this.home4x1Mode = 0,
    this.customBoxColors = const [],
    this.customTextColors = const [],
    this.customAccentColors = const [],
  });

  Color get boxColor => Color(boxColorValue).withValues(alpha: opacity.clamp(0.0, 1.0));
  Color get rawBoxColor => Color(boxColorValue);
  Color get textColor => Color(textColorValue);
  Color get subTextColor => Color(textColorValue).withValues(alpha: 0.62);
  Color get accentColor => Color(accentColorValue);
  Color get borderColor =>
      Color(accentColorValue).withValues(alpha: (opacity * 0.45).clamp(0.15, 0.6));

  WidgetStyle copyWith({
    double? opacity,
    int? boxColorValue,
    int? textColorValue,
    int? accentColorValue,
    int? wallpaperPreset,
    int? home4x1Mode,
    List<int>? customBoxColors,
    List<int>? customTextColors,
    List<int>? customAccentColors,
  }) =>
      WidgetStyle(
        opacity: opacity ?? this.opacity,
        boxColorValue: boxColorValue ?? this.boxColorValue,
        textColorValue: textColorValue ?? this.textColorValue,
        accentColorValue: accentColorValue ?? this.accentColorValue,
        wallpaperPreset: wallpaperPreset ?? this.wallpaperPreset,
        home4x1Mode: home4x1Mode ?? this.home4x1Mode,
        customBoxColors: customBoxColors ?? this.customBoxColors,
        customTextColors: customTextColors ?? this.customTextColors,
        customAccentColors: customAccentColors ?? this.customAccentColors,
      );

  Map<String, dynamic> toJson() => {
        'opacity': opacity,
        'boxColor': boxColorValue,
        'textColor': textColorValue,
        'accentColor': accentColorValue,
        'wallpaperPreset': wallpaperPreset,
        'home4x1Mode': home4x1Mode,
        'customBoxColors': customBoxColors,
        'customTextColors': customTextColors,
        'customAccentColors': customAccentColors,
      };

  static WidgetStyle fromJson(Map<String, dynamic>? m) {
    if (m == null) return const WidgetStyle();
    List<int> parseInts(dynamic v) =>
        v is List ? v.whereType<num>().map((e) => e.toInt()).toList() : const [];
    return WidgetStyle(
      opacity: (m['opacity'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.75,
      boxColorValue: (m['boxColor'] as num?)?.toInt() ?? 0xFF0A0A0A,
      textColorValue: (m['textColor'] as num?)?.toInt() ?? 0xFFFFFFFF,
      accentColorValue: (m['accentColor'] as num?)?.toInt() ?? 0xFFD8C3A5,
      wallpaperPreset: (m['wallpaperPreset'] as num?)?.toInt() ?? 0,
      home4x1Mode: ((m['home4x1Mode'] as num?)?.toInt() ?? 0).clamp(0, 2),
      customBoxColors: parseInts(m['customBoxColors']),
      customTextColors: parseInts(m['customTextColors']),
      customAccentColors: parseInts(m['customAccentColors']),
    );
  }
}

/// 기본 제공 색상 프리셋
const List<int> kDefaultBoxColors = [
  0xFF0A0A0A, // 퓨어 블랙
  0xFF18181B, // 차콜 다크
  0xFF1E1815, // 에스프레소 다크
  0xFF0F172A, // 딥 네이비
  0xFF14211D, // 딥 포레스트
  0xFFF5F2EB, // 크림 아이보리 (밝은 모래 배경 추천)
  0xFFFFFFFF, // 퓨어 화이트 (밝은 배경용)
];

const List<int> kDefaultTextColors = [
  0xFFFFFFFF, // 화이트 (어두운 배경 기본)
  0xFF1F1A17, // 딥 에스프레소 차콜 (밝은 모래 배경 추천 기본)
  0xFF2C221E, // 로스티드 브라운
  0xFF111111, // 잉크 오프블랙
  0xFFF5EFE6, // 웜 아이보리
  0xFFD8C3A5, // 샌드베이지
  0xFFCBD5E1, // 실버 그레이
];

const List<int> kDefaultAccentColors = [
  0xFFD8C3A5, // 샌드베이지 (어두운 배경 기본)
  0xFF7A5230, // 웜 브론즈 오크 (밝은 모래 배경 추천 기본)
  0xFFB85038, // 번트 테라코타 (밝은 모래 포인트)
  0xFF4A5D4E, // 딥 올리브 세이지 (밝은 모래 포인트)
  0xFFFFFFFF, // 퓨어 화이트
  0xFFE6C280, // 샴페인 골드
  0xFF1F1A17, // 미니멀 에스프레소 블랙
];

class MementoLockApp extends StatelessWidget {
  const MementoLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memento Lock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'MementoSans',
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: kSandBeige,
          onPrimary: Colors.black,
          surface: Colors.black,
          onSurface: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

/// 개별 D-Day 목표
class Goal {
  final String title;
  final DateTime date;
  const Goal(this.title, this.date);

  Map<String, dynamic> toJson() => {
        'title': title,
        'date': date.toIso8601String(),
      };

  static Goal? fromJson(Map<String, dynamic> m) {
    final d = DateTime.tryParse(m['date'] as String? ?? '');
    final t = (m['title'] as String? ?? '').trim();
    if (d == null || t.isEmpty) return null;
    return Goal(t, d);
  }
}

/// 사용자 설정 (생년월일 + D-Day 목록 + 명언 노출 모드 + 위젯 스타일 + 잠금화면 노출 D-Day 인덱스 최대 2개)
class Profile {
  final DateTime birth;
  final List<Goal> goals;
  final QuoteMode quoteMode;
  final WidgetStyle widgetStyle;
  final List<int> pinnedGoalIndices;

  const Profile(
    this.birth,
    this.goals, [
    this.quoteMode = QuoteMode.daily,
    this.widgetStyle = const WidgetStyle(),
    this.pinnedGoalIndices = const [0, 1],
  ]);

  Profile copyWith({
    DateTime? birth,
    List<Goal>? goals,
    QuoteMode? quoteMode,
    WidgetStyle? widgetStyle,
    List<int>? pinnedGoalIndices,
  }) =>
      Profile(
        birth ?? this.birth,
        goals ?? this.goals,
        quoteMode ?? this.quoteMode,
        widgetStyle ?? this.widgetStyle,
        pinnedGoalIndices ?? this.pinnedGoalIndices,
      );
}

/// 설정 저장/불러오기 및 실제 폰 홈화면 위젯(AppWidget) 실시간 동기화 담당
class ProfileStore {
  static const _birthKey = 'birth';
  static const _goalsKey = 'goals';
  static const _quoteModeKey = 'quoteMode';
  static const _widgetStyleKey = 'widgetStyle';
  static const _pinnedGoalsKey = 'pinnedGoals';
  static const _lastQuoteKey = 'lastQuote';
  static const _legacyGoalDateKey = 'target';
  static const _legacyGoalTitleKey = 'goalTitle';
  static const MethodChannel _widgetChannel =
      MethodChannel('com.mementolock.memento_lock/widgets');

  static Future<void> syncNativeWidgets([String? quote]) async {
    try {
      if (quote != null) {
        final p = await SharedPreferences.getInstance();
        await p.setString(_lastQuoteKey, quote);
      }
      await _widgetChannel.invokeMethod('updateWidgets');
    } catch (_) {}
  }

  static Future<bool> requestPinNativeWidget(String kind) async {
    try {
      final ok = await _widgetChannel.invokeMethod<bool>('requestPinWidget', {'kind': kind});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<Profile?> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final birth = DateTime.tryParse(p.getString(_birthKey) ?? '');
      if (birth == null) return null;

      final goals = <Goal>[];
      final rawList = p.getStringList(_goalsKey);
      if (rawList != null) {
        for (final item in rawList) {
          try {
            final g = Goal.fromJson(jsonDecode(item) as Map<String, dynamic>);
            if (g != null) goals.add(g);
          } catch (_) {}
        }
      } else {
        final legacyDate = DateTime.tryParse(p.getString(_legacyGoalDateKey) ?? '');
        if (legacyDate != null) {
          goals.add(Goal(p.getString(_legacyGoalTitleKey) ?? '나의 목표', legacyDate));
        }
      }

      final modeStr = p.getString(_quoteModeKey);
      final mode = modeStr == QuoteMode.everyTime.name ? QuoteMode.everyTime : QuoteMode.daily;

      WidgetStyle style = const WidgetStyle();
      final rawStyle = p.getString(_widgetStyleKey);
      if (rawStyle != null) {
        try {
          style = WidgetStyle.fromJson(jsonDecode(rawStyle) as Map<String, dynamic>);
        } catch (_) {}
      }

      final rawPinned = p.getStringList(_pinnedGoalsKey);
      final pinned = rawPinned != null
          ? rawPinned.map((e) => int.tryParse(e)).whereType<int>().toList()
          : <int>[0, 1];

      return Profile(birth, goals, mode, style, pinned);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(Profile v) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_birthKey, v.birth.toIso8601String());
      await p.setStringList(
        _goalsKey,
        v.goals.map((g) => jsonEncode(g.toJson())).toList(),
      );
      await p.setString(_quoteModeKey, v.quoteMode.name);
      await p.setString(_widgetStyleKey, jsonEncode(v.widgetStyle.toJson()));
      await p.setStringList(
        _pinnedGoalsKey,
        v.pinnedGoalIndices.map((i) => i.toString()).toList(),
      );
      await p.setString(_lastQuoteKey, pickQuote(v.quoteMode));
      await syncNativeWidgets();
    } catch (_) {}
  }
}

DateTime _day(DateTime x) => DateTime(x.year, x.month, x.day);

/// 숫자 문자열(예: "19950515" 또는 "1995.05.15")을 날짜로 변환
DateTime? parseBirthInput(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length != 8) return null;
  final y = int.tryParse(digits.substring(0, 4));
  final m = int.tryParse(digits.substring(4, 6));
  final d = int.tryParse(digits.substring(6, 8));
  if (y == null || m == null || d == null) return null;
  if (y < 1900 || y > 2200 || m < 1 || m > 12 || d < 1 || d > 31) return null;
  final dt = DateTime(y, m, d);
  if (dt.year != y || dt.month != m || dt.day != d) return null;
  return dt;
}

/// 6자리 HEX 문자열(예: "D8C3A5" 또는 "#D8C3A5")을 색상 정수로 변환
int? parseHexColor(String input) {
  final cleaned = input.trim().replaceAll('#', '').toUpperCase();
  if (!RegExp(r'^[0-9A-F]{6}$').hasMatch(cleaned)) return null;
  final rgb = int.tryParse(cleaned, radix: 16);
  if (rgb == null) return null;
  return 0xFF000000 | rgb;
}

/// 인생 게이지: 80세를 끝으로 잡고 지나간 비율(%) 계산
double lifePercent(DateTime birth, [DateTime? now]) {
  final b = _day(birth);
  final end = DateTime(b.year + kLifeExpectancyYears, b.month, b.day);
  final total = end.difference(b).inDays;
  final lived = _day(now ?? DateTime.now()).difference(b).inDays;
  return (lived / total * 100).clamp(0, 100).toDouble();
}

/// 태어난 날부터 오늘까지 살아온 날짜 수 (D+day용)
int daysLived(DateTime birth, [DateTime? now]) =>
    max(0, _day(now ?? DateTime.now()).difference(_day(birth)).inDays);

/// 살아온 날 표기 (예: "D+11,496")
String livedDayLabel(DateTime birth, [DateTime? now]) =>
    'D+${NumberFormat('#,###').format(daysLived(birth, now))}';

/// 목표일까지 남은 날 (지나면 음수)
int daysUntil(DateTime goal, [DateTime? now]) =>
    _day(goal).difference(_day(now ?? DateTime.now())).inDays;

String ddayLabel(int d) => d > 0 ? 'D-$d' : (d == 0 ? 'D-DAY' : 'D+${-d}');

/// 올해(1월 1일 ~ 12월 31일) 경과율(%) 계산
double yearElapsedPercent([DateTime? now]) {
  final t = now ?? DateTime.now();
  final start = DateTime(t.year, 1, 1);
  final end = DateTime(t.year + 1, 1, 1);
  final totalSeconds = end.difference(start).inSeconds;
  final elapsedSeconds = t.difference(start).inSeconds;
  return (elapsedSeconds / totalSeconds * 100).clamp(0.0, 100.0);
}

/// 오늘 하루(00:00 ~ 24:00) 경과율(%) 계산
double todayElapsedPercent([DateTime? now]) {
  final t = now ?? DateTime.now();
  final secondsToday = t.hour * 3600 + t.minute * 60 + t.second;
  return (secondsToday / 86400 * 100).clamp(0.0, 100.0);
}

/// 80세까지 남은 일수 계산
int remainingLifeDays(DateTime birth, [DateTime? now]) {
  final b = _day(birth);
  final end = DateTime(b.year + kLifeExpectancyYears, b.month, b.day);
  final cur = _day(now ?? DateTime.now());
  return max(0, end.difference(cur).inDays);
}

/// 80세까지 남은 주말(토/일 묶음 = 주) 횟수 계산
int remainingLifeWeekends(DateTime birth, [DateTime? now]) =>
    (remainingLifeDays(birth, now) / 7).floor();

/// 메멘토 모리 · 시간 · 실행 명언 95선 (강렬한 50선 + 깊이 있는 45선)
const List<String> kQuotes = [
  '변명하지 마라. 시체에게는 핑계가 필요 없다.',
  '네가 무의미하게 스크롤을 내리는 지금, 네 수명도 함께 깎여 나가고 있다.',
  '오늘을 죽이지 마라. 네가 죽인 오늘이 결국 너를 묻을 것이다.',
  '내일부터 하겠다는 말은, 오늘의 나를 포기하겠다는 항복 선언이다.',
  '묘비에 "늘 피곤해서 미루다 죽었다"라고 적히고 싶은가?',
  '네가 안전지대라고 부르는 그곳은 사실 서서히 식어가는 관 속이다.',
  '아무것도 하지 않으면 아무 일도 일어나지 않고, 그러다 그냥 끝난다.',
  '죽음은 예약 없이 찾아온다. 오늘이 마지막이어도 부끄럽지 않은가?',
  '게으름은 할부로 치르는 자살이다.',
  '네가 아끼는 그 알량한 자존심보다, 지금 흘러가는 1분이 훨씬 비싸다.',
  '잠깐의 편안함과 평생의 후회 중 하나는 반드시 치러야 한다.',
  '너는 시간이 부족한 게 아니다. 간절함이 부족한 것이다.',
  '10년 뒤의 네가 지금의 너를 보며 피눈물을 흘리지 않게 하라.',
  '생각만 하고 움직이지 않는 뇌는 살아있는 시체와 다를 바 없다.',
  '남의 인생 구경하느라 네 인생의 시계가 멈추는 줄도 모르고 있다.',
  '죽음 앞에서는 네가 가진 모든 핑계가 단 한 줄도 통하지 않는다.',
  '지금 이 순간에도 모래시계의 모래는 위에서 아래로만 떨어진다. 뒤집을 기회는 없다.',
  '하고 싶은 일을 미루는 건, 살아있기를 미루는 것이다.',
  '네가 흘려보낸 1시간은 그 어떤 억만장자도 다시 사지 못한다.',
  '고통 없이 얻는 것은 노화와 죽음뿐이다.',
  '열정 없이 사는 것은 이미 절반쯤 죽어 있는 상태다.',
  '오늘 타오르지 않으면, 내일은 재조차 남지 않는다.',
  '운명을 탓하지 마라. 어제 네가 한 선택이 오늘의 네 모습이다.',
  '기회가 오지 않는다고 불평하지 마라. 와도 잡을 준비가 안 되어 있지 않은가.',
  '네 인생의 관객으로 살다 끝낼 셈인가, 주인공으로 피 흘릴 셈인가.',
  '시간을 죽이는 자는 결국 시간에게 살해당한다.',
  '두려워서 멈춘 자리에서 네 가능성도 함께 썩어간다.',
  '오늘의 타협이 내일의 비굴함을 만든다.',
  '아직 시간이 많다는 착각이 인간을 가장 비참하게 무너뜨린다.',
  '네 심장은 영원히 뛰지 않는다. 횟수가 정해져 있다.',
  '완벽한 환경을 기다리는 사람은 영원히 출발선에서 늙어 죽는다.',
  '지옥은 다른 곳이 아니다. 내가 될 수 있었던 모습을 임종 직전에 마주하는 것이다.',
  '하루를 대충 사는 사람은 인생 전체를 대충 사는 사람이다.',
  '네가 미룬 꿈은 사라지지 않고, 늙은 너를 괴롭히는 망령이 된다.',
  '죽음을 직시하라. 쓸데없는 고민의 99%가 즉시 증발할 것이다.',
  '아무도 네 인생을 대신 살아주지 않고, 아무도 네 죽음을 대신 맞아주지 않는다.',
  '오늘 흘리지 않은 땀은 내일 눈물로 환산되어 청구된다.',
  '적당히 살다 가기엔 세상에 태어날 확률이 너무나도 기적이었다.',
  '네가 지금 외면하는 문제가 5년 뒤 네 목줄을 죌 것이다.',
  '편안함은 성장을 멈추게 하는 가장 달콤한 독약이다.',
  '임종의 침대에서 "남들 눈치 보느라 내 삶을 못 살았다"고 울 것인가?',
  '집중하지 않는 삶은 안개 속을 헤매다 절벽에서 떨어지는 것과 같다.',
  '지금 당장 움직여라. 기분은 행동의 뒤를 따를 뿐이다.',
  '네가 포기하려는 그 순간이, 어제의 네가 그토록 오고 싶어 했던 자리다.',
  '살아있다는 증거를 보여라. 숨만 쉰다고 살아있는 게 아니다.',
  '인생에는 리허설이 없다. 지금 이 순간이 본방이며 생방송이다.',
  '네가 낭비한 젊음은 늙어서 가장 비싼 이자로 갚아야 한다.',
  '세상이 널 버린 게 아니라, 네가 스스로의 시간을 버리고 있는 것이다.',
  '주저하는 사이 기회는 옆 사람의 손으로 넘어간다.',
  '기억하라. 네가 보낸 오늘 하루는 인생에서 영구 삭제된 1일이다.',
  '오늘은 다시 오지 않는다.',
  '기억하라, 너는 언젠가 죽는다. — Memento Mori',
  '시간은 우리가 가진 가장 비싼 화폐다.',
  '지금 이 순간이 곧 당신의 인생이다.',
  '내일로 미루기엔 오늘 하루가 너무 짧다.',
  '남은 날을 세지 말고, 오늘을 의미 있게 채워라.',
  '작은 하루가 모여 한 생이 된다.',
  '인생이 짧은 것이 아니라, 우리가 많은 시간을 낭비하는 것이다. — 세네카',
  '당신이 지금 흘려보내는 오늘은 어제 죽은 이가 그토록 원하던 내일이다.',
  '언젠가라는 날은 달력에 없다.',
  '죽음을 기억하는 것은 삶을 가장 뜨겁게 사랑하는 방법이다.',
  '완벽한 때를 기다리지 마라. 지금이 바로 그때다.',
  '우리는 영원히 살 것처럼 계획하고, 오늘이 마지막인 것처럼 후회한다.',
  '아침에 눈을 떴다면, 오늘이라는 선물을 받은 것이다.',
  '가장 큰 위험은 아무런 위험도 감수하지 않는 것이다.',
  '시간은 누구에게나 공평하게 흐르지만, 누구에게나 같은 밀도로 남지 않는다.',
  '당신의 유한함이 당신의 모든 선택을 특별하게 만든다.',
  '지금 당장 시작하라. 1년 뒤의 당신이 오늘의 당신에게 감사할 것이다.',
  '살아있는 동안 삶에 충실하라. — 마르쿠스 아우렐리우스',
  '운명을 사랑하라. — Amor Fati',
  '생각하는 대로 살지 않으면, 사는 대로 생각하게 된다.',
  '오늘 심은 작은 습관이 내일의 운명을 만든다.',
  '과거는 바꿀 수 없지만, 오늘의 방향은 지금 바꿀 수 있다.',
  '두려움은 잠깐이지만, 해보지 않은 후회는 평생 남는다.',
  '인생의 길이는 우리가 정할 수 없지만, 깊이는 우리가 정할 수 있다.',
  '남의 시선에 쓰기엔 내 인생의 모래시계가 너무 빠르게 줄어든다.',
  '중요한 일에 시간을 써라. 사소한 일은 저절로 빈틈을 채운다.',
  '매일 밤 잠들기 전, 오늘 하루를 기꺼이 내어주었는지 자문하라.',
  '진정으로 산 날만이 당신의 나이로 계산되어야 한다.',
  '흔들려도 좋다. 멈추지만 않으면 결국 도착한다.',
  '가장 어두운 밤도 결국 새벽에 자리를 내어준다.',
  '우리가 통제할 수 있는 유일한 시간은 바로 지금뿐이다.',
  '더 적게 소유하고, 더 깊이 존재하라.',
  '끝을 알고 걷는 사람은 걸음마다 방향을 잃지 않는다.',
  '할 수 있다고 믿든, 할 수 없다고 믿든 당신의 믿음대로 된다.',
  '인생은 속도가 아니라 방향과 밀도다.',
  '오늘 아낀 용기는 내일로 이월되지 않는다.',
  '삶을 미루는 동안 삶은 우리를 스쳐 지나간다. — 세네카',
  '무엇을 위해 살 것인가를 아는 사람은 어떤 시련도 견뎌낸다. — 니체',
  '행동 없는 다짐은 가장 조용한 시간 낭비다.',
  '당신의 시간을 아끼는 것이 곧 당신 자신을 아끼는 것이다.',
  '단 한 번뿐인 생이다. 가볍게 흘려보내지 마라.',
  '오늘의 집중이 내일의 자유를 만든다.',
  '마지막 순간에 웃을 수 있도록, 오늘을 살아라.',
  '지금 숨 쉬고 있는 이 순간이 가장 젊은 날이다.',
];

/// 날짜 기반 고정 랜덤(하루 1회) 또는 호출 시마다 랜덤 명언 선택
String pickQuote(QuoteMode mode, {DateTime? now, int? randomSeed}) {
  if (mode == QuoteMode.everyTime) {
    final rng = randomSeed != null ? Random(randomSeed) : Random();
    return kQuotes[rng.nextInt(kQuotes.length)];
  }
  final d = _day(now ?? DateTime.now());
  final seed = d.year * 10000 + d.month * 100 + d.day;
  final rng = Random(seed);
  return kQuotes[rng.nextInt(kQuotes.length)];
}

/// 가시성이 뛰어나고 월이 숫자(1월~12월)로 명확히 보이는 커스텀 달력 다이얼로그
/// + iOS 스타일 연/월/일 휠 피커 & 숫자 키패드 탭 모두 지원하여 모바일/에뮬레이터에서도 100% 입력 가능
Future<DateTime?> showMementoDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = '날짜 선택',
}) {
  DateTime selected = _day(initialDate);
  if (selected.isBefore(_day(firstDate))) selected = _day(firstDate);
  if (selected.isAfter(_day(lastDate))) selected = _day(lastDate);
  DateTime displayedMonth = DateTime(selected.year, selected.month, 1);
  int inputTab = 0; // 0: 달력 선택, 1: iOS 휠 피커 (연/월/일 빠르게 굴리기)

  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        final year = displayedMonth.year;
        final month = displayedMonth.month;
        final daysInMonth = DateTime(year, month + 1, 0).day;
        final firstWeekdayOffset = DateTime(year, month, 1).weekday % 7;
        final today = _day(DateTime.now());

        void changeMonth(int delta) {
          final next = DateTime(year, month + delta, 1);
          if (next.year < firstDate.year || next.year > lastDate.year) return;
          setModalState(() => displayedMonth = next);
        }

        void selectYearMonthDay(int y, int m, [int? d]) {
          final maxDay = DateTime(y, m + 1, 0).day;
          final safeDay = (d ?? selected.day).clamp(1, maxDay);
          var candidate = DateTime(y, m, safeDay);
          if (candidate.isBefore(_day(firstDate))) candidate = _day(firstDate);
          if (candidate.isAfter(_day(lastDate))) candidate = _day(lastDate);
          setModalState(() {
            selected = candidate;
            displayedMonth = DateTime(candidate.year, candidate.month, 1);
          });
        }

        return AlertDialog(
          backgroundColor: const Color(0xFF141414),
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: kSandBeige, width: 1.2),
          ),
          titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          contentPadding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 14, color: kSandBeige, letterSpacing: 1)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF241E17),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: kSandBeigeDim),
                    ),
                    child: Text(
                      DateFormat('yyyy년 MM월 dd일').format(selected),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: kSandBeige),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 모드 전환 탭: [달력에서 터치] vs [iOS 휠로 연·월·일 빠른 선택]
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setModalState(() => inputTab = 0),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: inputTab == 0 ? kSandBeige : Colors.black,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: inputTab == 0 ? kSandBeige : Colors.white24),
                        ),
                        child: Text(
                          '달력으로 선택',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: inputTab == 0 ? Colors.black : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => setModalState(() => inputTab = 1),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: inputTab == 1 ? kSandBeige : Colors.black,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: inputTab == 1 ? kSandBeige : Colors.white24),
                        ),
                        child: Text(
                          '연·월·일 빠른 휠 (iOS형)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: inputTab == 1 ? Colors.black : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: inputTab == 1
                  ? SizedBox(
                      height: 220,
                      child: Row(
                        children: [
                          // 연도 휠
                          Expanded(
                            flex: 4,
                            child: CupertinoPicker(
                              scrollController: FixedExtentScrollController(
                                initialItem: (selected.year - firstDate.year)
                                    .clamp(0, lastDate.year - firstDate.year),
                              ),
                              itemExtent: 38,
                              onSelectedItemChanged: (idx) {
                                selectYearMonthDay(firstDate.year + idx, selected.month);
                              },
                              children: [
                                for (int y = firstDate.year; y <= lastDate.year; y++)
                                  Center(
                                    child: Text('$y년',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 16)),
                                  ),
                              ],
                            ),
                          ),
                          // 월 휠
                          Expanded(
                            flex: 3,
                            child: CupertinoPicker(
                              scrollController: FixedExtentScrollController(
                                initialItem: selected.month - 1,
                              ),
                              itemExtent: 38,
                              onSelectedItemChanged: (idx) {
                                selectYearMonthDay(selected.year, idx + 1);
                              },
                              children: [
                                for (int m = 1; m <= 12; m++)
                                  Center(
                                    child: Text('${m.toString().padLeft(2, '0')}월',
                                        style: const TextStyle(
                                            color: kSandBeige,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600)),
                                  ),
                              ],
                            ),
                          ),
                          // 일 휠
                          Expanded(
                            flex: 3,
                            child: CupertinoPicker(
                              scrollController: FixedExtentScrollController(
                                initialItem: (selected.day - 1).clamp(0, 30),
                              ),
                              itemExtent: 38,
                              onSelectedItemChanged: (idx) {
                                selectYearMonthDay(selected.year, selected.month, idx + 1);
                              },
                              children: [
                                for (int d = 1;
                                    d <= DateTime(selected.year, selected.month + 1, 0).day;
                                    d++)
                                  Center(
                                    child: Text('${d.toString().padLeft(2, '0')}일',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 16)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                tooltip: '이전 달',
                                icon: const Icon(Icons.chevron_left, color: kSandBeige),
                                onPressed: () => changeMonth(-1),
                              ),
                              Row(
                                children: [
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: year,
                                      dropdownColor: const Color(0xFF1E1E1E),
                                      style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white),
                                      items: [
                                        for (int y = firstDate.year; y <= lastDate.year; y++)
                                          DropdownMenuItem(value: y, child: Text('$y년')),
                                      ],
                                      onChanged: (y) {
                                        if (y != null) selectYearMonthDay(y, month);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: month,
                                      dropdownColor: const Color(0xFF1E1E1E),
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: kSandBeige),
                                      items: [
                                        for (int m = 1; m <= 12; m++)
                                          DropdownMenuItem(
                                            value: m,
                                            child: Text('${m.toString().padLeft(2, '0')}월'),
                                          ),
                                      ],
                                      onChanged: (m) {
                                        if (m != null) selectYearMonthDay(year, m);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                tooltip: '다음 달',
                                icon: const Icon(Icons.chevron_right, color: kSandBeige),
                                onPressed: () => changeMonth(1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 28,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: 12,
                            separatorBuilder: (_, _) => const SizedBox(width: 4),
                            itemBuilder: (_, idx) {
                              final m = idx + 1;
                              final isCurMonth = m == month;
                              return InkWell(
                                onTap: () => selectYearMonthDay(year, m),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isCurMonth ? kSandBeige : Colors.black,
                                    border: Border.all(
                                        color: isCurMonth ? kSandBeige : Colors.white24),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$m월',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight:
                                          isCurMonth ? FontWeight.w700 : FontWeight.w400,
                                      color: isCurMonth ? Colors.black : Colors.white70,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: const [
                            _WeekdayHeader('일', color: Color(0xFFFF8A80)),
                            _WeekdayHeader('월'),
                            _WeekdayHeader('화'),
                            _WeekdayHeader('수'),
                            _WeekdayHeader('목'),
                            _WeekdayHeader('금'),
                            _WeekdayHeader('토', color: Color(0xFF82B1FF)),
                          ],
                        ),
                        const Divider(color: Colors.white24, height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                            childAspectRatio: 1.15,
                          ),
                          itemCount: firstWeekdayOffset + daysInMonth,
                          itemBuilder: (_, index) {
                            if (index < firstWeekdayOffset) return const SizedBox.shrink();
                            final dayNum = index - firstWeekdayOffset + 1;
                            final cellDate = DateTime(year, month, dayNum);
                            final isSelected = cellDate == selected;
                            final isToday = cellDate == today;
                            final disabled = cellDate.isBefore(_day(firstDate)) ||
                                cellDate.isAfter(_day(lastDate));

                            return InkWell(
                              onTap: disabled
                                  ? null
                                  : () => setModalState(() => selected = cellDate),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? kSandBeige
                                      : (isToday
                                          ? const Color(0xFF26211A)
                                          : Colors.transparent),
                                  borderRadius: BorderRadius.circular(6),
                                  border: isToday && !isSelected
                                      ? Border.all(color: kSandBeige, width: 1.2)
                                      : Border.all(color: Colors.white10),
                                ),
                                child: Text(
                                  '$dayNum',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected || isToday
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: disabled
                                        ? Colors.white24
                                        : (isSelected ? Colors.black : Colors.white),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setModalState(() {
                  selected = today;
                  displayedMonth = DateTime(today.year, today.month, 1);
                });
              },
              child: const Text('오늘로 이동', style: TextStyle(color: kSandBeige)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소', style: TextStyle(color: Colors.white54)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: kSandBeige,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('선택 완료', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    ),
  );
}

class _WeekdayHeader extends StatelessWidget {
  final String text;
  final Color color;
  const _WeekdayHeader(this.text, {this.color = Colors.white70});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
        ),
      ),
    );
  }
}

/// 새 색상 옵션 추가 다이얼로그 (RGB 슬라이더 + HEX 코드 직접 입력)
Future<int?> showAddColorDialog(BuildContext context, {required String categoryName}) async {
  int r = 216, g = 195, b = 165;
  final hexCtrl = TextEditingController(text: 'D8C3A5');
  String? errorText;

  void syncHexFromRgb() {
    hexCtrl.text =
        '${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'
            .toUpperCase();
  }

  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        final previewColor = Color.fromARGB(255, r, g, b);
        return AlertDialog(
          backgroundColor: const Color(0xFF141414),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: kSandBeige),
          ),
          title: Text('$categoryName 색상 옵션 추가',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 색상 미리보기 박스
                Container(
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: previewColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white38),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '#${hexCtrl.text}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: previewColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: hexCtrl,
                  maxLength: 6,
                  decoration: InputDecoration(
                    prefixText: '# ',
                    labelText: 'HEX 색상 코드 (6자리)',
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    final parsed = parseHexColor(v);
                    if (parsed != null) {
                      setModalState(() {
                        r = (parsed >> 16) & 0xFF;
                        g = (parsed >> 8) & 0xFF;
                        b = parsed & 0xFF;
                        errorText = null;
                      });
                    } else {
                      setModalState(() => errorText = '0~9, A~F 6자리를 입력해 주세요');
                    }
                  },
                ),
                const SizedBox(height: 8),
                _RgbSliderRow(
                  label: 'R',
                  value: r,
                  activeColor: Colors.redAccent,
                  onChanged: (v) => setModalState(() {
                    r = v;
                    errorText = null;
                    syncHexFromRgb();
                  }),
                ),
                _RgbSliderRow(
                  label: 'G',
                  value: g,
                  activeColor: Colors.greenAccent,
                  onChanged: (v) => setModalState(() {
                    g = v;
                    errorText = null;
                    syncHexFromRgb();
                  }),
                ),
                _RgbSliderRow(
                  label: 'B',
                  value: b,
                  activeColor: Colors.lightBlueAccent,
                  onChanged: (v) => setModalState(() {
                    b = v;
                    errorText = null;
                    syncHexFromRgb();
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소', style: TextStyle(color: Colors.white54)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: kSandBeige,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final c = parseHexColor(hexCtrl.text) ?? (0xFF000000 | (r << 16) | (g << 8) | b);
                Navigator.pop(ctx, c);
              },
              child: const Text('팔레트에 추가', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    ),
  );
}

class _RgbSliderRow extends StatelessWidget {
  final String label;
  final int value;
  final Color activeColor;
  final ValueChanged<int> onChanged;

  const _RgbSliderRow({
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 18, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            activeColor: activeColor,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text('$value',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ),
      ],
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Profile? _profile;
  bool _loading = true;
  late String _currentQuote;
  bool _showCustomizer = false;
  bool _iosWidgetMode = false; // false: Android 위젯 프리뷰, true: iOS (iPhone WidgetKit) 프리뷰

  @override
  void initState() {
    super.initState();
    _currentQuote = pickQuote(QuoteMode.daily);
    ProfileStore.load().then((v) {
      if (!mounted) return;
      setState(() {
        _profile = v;
        if (v != null) {
          _currentQuote = pickQuote(v.quoteMode);
        }
        _loading = false;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  Future<void> _updateProfile(Profile next) async {
    // 1. UI에 먼저 즉시 반영 (슬라이더 끊김 및 비동기 역전 방지)
    setState(() => _profile = next);
    // 2. 로컬 저장소에 영구 저장
    await ProfileStore.save(next);
  }

  void _refreshQuote([QuoteMode? mode]) {
    final m = mode ?? _profile?.quoteMode ?? QuoteMode.daily;
    final nextQuote = pickQuote(
      m,
      randomSeed: m == QuoteMode.everyTime ? DateTime.now().microsecondsSinceEpoch : null,
    );
    setState(() {
      _currentQuote = nextQuote;
    });
    ProfileStore.syncNativeWidgets(nextQuote);
  }

  Future<void> _toggleQuoteMode() async {
    final p = _profile;
    if (p == null) return;
    final nextMode = p.quoteMode == QuoteMode.daily ? QuoteMode.everyTime : QuoteMode.daily;
    final updated = p.copyWith(quoteMode: nextMode);
    await ProfileStore.save(updated);
    setState(() {
      _profile = updated;
      _currentQuote = pickQuote(
        nextMode,
        randomSeed: nextMode == QuoteMode.everyTime ? DateTime.now().microsecondsSinceEpoch : null,
      );
    });
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push<Profile>(
      context,
      MaterialPageRoute(builder: (_) => SettingsPage(initial: _profile)),
    );
    if (result != null) {
      final q = pickQuote(result.quoteMode);
      await ProfileStore.save(result);
      await ProfileStore.syncNativeWidgets(q);
      if (!mounted) return;
      setState(() {
        _profile = result;
        _currentQuote = q;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF1E1B16),
          content: Text(
            '생년월일 및 설정이 저장되어 실제 폰 위젯에 즉시 반영되었습니다!',
            style: TextStyle(color: kSandBeige, fontSize: 12),
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _addGoalDirectly() async {
    final p = _profile;
    if (p == null) return;
    final added = await showGoalDialog(context);
    if (added != null) {
      final nextGoals = [...p.goals, added];
      final nextPinned = [...p.pinnedGoalIndices];
      if (nextPinned.length < 2 && !nextPinned.contains(nextGoals.length - 1)) {
        nextPinned.add(nextGoals.length - 1);
      }
      await _updateProfile(p.copyWith(goals: nextGoals, pinnedGoalIndices: nextPinned));
    }
  }

  Future<void> _removeGoalAt(int index) async {
    final p = _profile;
    if (p == null) return;
    final nextGoals = [...p.goals]..removeAt(index);
    final nextPinned = <int>[];
    for (final idx in p.pinnedGoalIndices) {
      if (idx == index) continue;
      nextPinned.add(idx > index ? idx - 1 : idx);
    }
    if (nextPinned.isEmpty && nextGoals.isNotEmpty) {
      nextPinned.add(0);
      if (nextGoals.length > 1) nextPinned.add(1);
    }
    await _updateProfile(p.copyWith(goals: nextGoals, pinnedGoalIndices: nextPinned));
  }

  /// 목표 카드를 탭하면 잠금화면 위젯 노출 대상(최대 2개)에 토글/순환 등록
  Future<void> _togglePinGoal(int index) async {
    final p = _profile;
    if (p == null) return;
    final pinned = [...p.pinnedGoalIndices].where((i) => i >= 0 && i < p.goals.length).toList();
    if (pinned.contains(index)) {
      if (pinned.length > 1) {
        pinned.remove(index);
      }
    } else {
      if (pinned.length >= 2) {
        pinned.removeAt(0);
      }
      pinned.add(index);
    }
    await _updateProfile(p.copyWith(pinnedGoalIndices: pinned));
  }

  /// 위젯에 노출할 최대 2개의 Goal 추출
  List<Goal> _resolvePinnedGoals(Profile p) {
    if (p.goals.isEmpty) return const [];
    final validIndices =
        p.pinnedGoalIndices.where((i) => i >= 0 && i < p.goals.length).toList();
    if (validIndices.isEmpty) {
      return p.goals.take(2).toList();
    }
    return validIndices.take(2).map((i) => p.goals[i]).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold();
    final p = _profile;
    if (p == null) return _Welcome(onStart: _openSettings);

    final now = DateTime.now();
    final pct = lifePercent(p.birth, now);
    final age = now.difference(p.birth).inDays ~/ 365.25;
    final livedStr = livedDayLabel(p.birth, now);
    final pinnedGoals = _resolvePinnedGoals(p);
    final ws = p.widgetStyle;
    const dim = TextStyle(color: Colors.white54, letterSpacing: 1);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          children: [
            // ── 상단 헤더 ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text('MEMENTO LOCK',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, letterSpacing: 3, color: kSandBeige)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      key: const Key('quoteModeToggle'),
                      onTap: _toggleQuoteMode,
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          p.quoteMode == QuoteMode.daily ? '명언: 하루 1회' : '명언: 볼 때마다',
                          style: const TextStyle(fontSize: 11, color: kSandBeige),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      key: const Key('settings'),
                      icon: const Icon(Icons.tune, color: Colors.white54),
                      onPressed: _openSettings,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── 인생 게이지 (80세 기준 + LIFE D+day + 샌드베이지 바) ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(pct.toStringAsFixed(2),
                            style: const TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.w200,
                                letterSpacing: -2,
                                height: 1)),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6, left: 4),
                          child: Text('%', style: TextStyle(fontSize: 20, color: kSandBeige)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  key: const Key('livedDaysBadge'),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171410),
                    border: Border.all(color: kSandBeigeDim),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('LIFE',
                          style: TextStyle(fontSize: 10, color: Colors.white54, letterSpacing: 2)),
                      const SizedBox(height: 2),
                      Text(
                        livedStr,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: kSandBeige,
                            letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '인생 게이지 · $age세 / $kLifeExpectancyYears세 · ${DateFormat('yyyy.MM.dd').format(p.birth)} (LIFE $livedStr)',
              style: dim,
            ),
            const SizedBox(height: 14),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct / 100),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  color: kSandBeige,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── 오늘의 명언 영역 ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: kCardBg,
                border: Border(left: BorderSide(color: kSandBeige, width: 2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _currentQuote,
                      style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          fontWeight: FontWeight.w300,
                          color: Colors.white),
                    ),
                  ),
                  IconButton(
                    key: const Key('shuffleQuote'),
                    tooltip: '다른 문구 보기 (총 ${kQuotes.length}선)',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.only(left: 8),
                    icon: const Icon(Icons.refresh, size: 18, color: kSandBeige),
                    onPressed: () => _refreshQuote(QuoteMode.everyTime),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── 위젯 디자인 & 스타일 커스터마이징 헤더 (좁은 화면에서도 절대 줄넘침 없도록 Wrap 배치) ──
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('위젯 미리보기',
                        style: TextStyle(fontSize: 12, letterSpacing: 1.5, color: Colors.white54)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1713),
                        border: Border.all(color: kSandBeigeDim),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '불투명도 ${(ws.opacity * 100).round()}% 저장됨',
                        style: const TextStyle(fontSize: 10, color: kSandBeige),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 배경화면 시뮬레이션 전환 버튼 (밝은 모래 전환 시 어울리는 기본 폰트·포인트 컬러 자동 추천 적용)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        final nextPreset = (ws.wallpaperPreset + 1) % 3;
                        WidgetStyle nextStyle = ws.copyWith(wallpaperPreset: nextPreset);
                        if (nextPreset == 1) {
                          // 밝은 모래 배경일 때: 딥 에스프레소 폰트(#1F1A17) + 웜 브론즈 포인트(#7A5230) + 크림 박스(#F5F2EB) 기본 적용
                          nextStyle = nextStyle.copyWith(
                            boxColorValue: 0xFFF5F2EB,
                            textColorValue: 0xFF1F1A17,
                            accentColorValue: 0xFF7A5230,
                          );
                        } else if (ws.wallpaperPreset == 1 &&
                            ws.textColorValue == 0xFF1F1A17) {
                          // 다시 어두운 배경으로 돌아올 때: 다크 기본값(블랙 박스 + 화이트 폰트 + 샌드베이지 포인트) 복원
                          nextStyle = nextStyle.copyWith(
                            boxColorValue: 0xFF0A0A0A,
                            textColorValue: 0xFFFFFFFF,
                            accentColorValue: 0xFFD8C3A5,
                          );
                        }
                        _updateProfile(p.copyWith(widgetStyle: nextStyle));
                      },
                      icon: const Icon(Icons.wallpaper, size: 13, color: kSandBeige),
                      label: Text(
                        ws.wallpaperPreset == 0
                            ? '배경: 노을'
                            : (ws.wallpaperPreset == 1 ? '배경: 밝은 모래' : '배경: 어두운 밤'),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      key: const Key('toggleWidgetCustomizer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _showCustomizer ? Colors.black : kSandBeige,
                        backgroundColor: _showCustomizer ? kSandBeige : Colors.transparent,
                        side: const BorderSide(color: kSandBeige),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      onPressed: () => setState(() => _showCustomizer = !_showCustomizer),
                      icon: const Icon(Icons.palette_outlined, size: 14),
                      label: Text(_showCustomizer ? '도구 닫기' : '투명도·컬러',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── 위젯 스타일 커스터마이징 도구 패널 ──
            if (_showCustomizer) ...[
              _WidgetStyleCustomizerPanel(
                style: ws,
                onChanged: (nextStyle) => _updateProfile(p.copyWith(widgetStyle: nextStyle)),
                onSaveAndClose: () async {
                  await ProfileStore.save(p);
                  if (!context.mounted) return;
                  setState(() => _showCustomizer = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF1E1B16),
                      content: Text(
                        '위젯 불투명도(${(ws.opacity * 100).round()}%) 및 컬러 설정이 저장되었습니다.',
                        style: const TextStyle(color: kSandBeige),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
            ],

            // ── 배경화면 시뮬레이션 캔버스 위에 위젯 2종 렌더링 (Android / iOS 전환 + 투명도 실시간 확인) ──
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: const Key('androidPreviewTab'),
                    onTap: () => setState(() => _iosWidgetMode = false),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: !_iosWidgetMode ? kSandBeige : const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: !_iosWidgetMode ? kSandBeige : Colors.white24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.android,
                              size: 14,
                              color: !_iosWidgetMode ? Colors.black : Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            'Android 위젯 디자인',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: !_iosWidgetMode ? Colors.black : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    key: const Key('iosPreviewTab'),
                    onTap: () => setState(() => _iosWidgetMode = true),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _iosWidgetMode ? kSandBeige : const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: _iosWidgetMode ? kSandBeige : Colors.white24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.phone_iphone,
                              size: 14,
                              color: _iosWidgetMode ? Colors.black : Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            'iOS (아이폰) 위젯 디자인',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _iosWidgetMode ? Colors.black : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
                gradient: _wallpaperGradient(ws.wallpaperPreset),
              ),
              child: _iosWidgetMode
                  ? _IosWidgetKitShowcase(
                      percent: pct,
                      age: age,
                      livedLabel: livedStr,
                      goals: pinnedGoals,
                      quote: _currentQuote,
                      style: ws,
                      now: now,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1) 잠금화면 위젯 (D-Day 최대 2개 동시 노출)
                        _LockScreenWidgetPreview(
                          percent: pct,
                          age: age,
                          livedLabel: livedStr,
                          goals: pinnedGoals,
                          quote: _currentQuote,
                          style: ws,
                          now: now,
                        ),
                        const SizedBox(height: 14),

                        // 2) 일반 홈화면 4x1 위젯 (명언 미노출 · 3가지 가운데 정보 옵션 전환 지원)
                        _Home4x1WidgetPreview(
                          percent: pct,
                          birth: p.birth,
                          livedLabel: livedStr,
                          goals: pinnedGoals,
                          style: ws,
                          now: now,
                          onChangeMode: (nextMode) =>
                              _updateProfile(p.copyWith(widgetStyle: ws.copyWith(home4x1Mode: nextMode))),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            // ── 실제 폰 바탕화면(홈화면)에 위젯 즉시 추가/동기화 버튼 ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('pinLockWidgetBtn'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kSandBeige,
                      backgroundColor: const Color(0xFF14120F),
                      side: const BorderSide(color: kSandBeigeDim),
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () async {
                      await ProfileStore.syncNativeWidgets(_currentQuote);
                      final pinned = await ProfileStore.requestPinNativeWidget('lock');
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF1E1B16),
                          content: Text(
                            pinned
                                ? '폰 홈화면에 [잠금화면·명언형 위젯] 추가 창을 열었습니다!'
                                : '위젯 데이터가 동기화되었습니다. 폰 바탕화면을 길게 눌러 [위젯] ➔ [Memento Lock]을 추가하세요.',
                            style: const TextStyle(color: kSandBeige, fontSize: 12),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_to_home_screen, size: 15),
                    label: const Text('폰 바탕화면에 명언형 위젯 추가',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('pinHome4x1WidgetBtn'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kSandBeige,
                      backgroundColor: const Color(0xFF14120F),
                      side: const BorderSide(color: kSandBeigeDim),
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () async {
                      await ProfileStore.syncNativeWidgets(_currentQuote);
                      final pinned = await ProfileStore.requestPinNativeWidget('home4x1');
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF1E1B16),
                          content: Text(
                            pinned
                                ? '폰 홈화면에 [4×1 배너 위젯] 추가 창을 열었습니다!'
                                : '위젯 데이터가 동기화되었습니다. 폰 바탕화면을 길게 눌러 [위젯] ➔ [Memento Lock]을 추가하세요.',
                            style: const TextStyle(color: kSandBeige, fontSize: 12),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.widgets_outlined, size: 15),
                    label: const Text('폰 바탕화면에 4×1 위젯 추가',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── 나의 목표 D-Day 헤더 + [추가] 버튼 ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('나의 D-DAY 목록',
                          style: TextStyle(fontSize: 12, letterSpacing: 2, color: Colors.white54)),
                      SizedBox(height: 2),
                      Text('카드를 탭하면 잠금화면 위젯에 최대 2개까지 선택됩니다',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.white38)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const Key('addGoalHome'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kSandBeige,
                    side: const BorderSide(color: kSandBeigeDim),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: _addGoalDirectly,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('추가', style: TextStyle(fontSize: 12, letterSpacing: 1)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (p.goals.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: TextButton.icon(
                    onPressed: _addGoalDirectly,
                    icon: const Icon(Icons.add, color: kSandBeige),
                    label: const Text('첫 D-Day 목표를 추가해 보세요',
                        style: TextStyle(color: Colors.white54)),
                  ),
                ),
              )
            else
              ...List.generate(p.goals.length, (i) {
                final g = p.goals[i];
                final pinOrder = p.pinnedGoalIndices.indexOf(i);
                final isSelected = pinOrder != -1 && pinOrder < 2;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => _togglePinGoal(i),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF14120F) : Colors.black,
                        border: Border.all(
                          color: isSelected ? kSandBeige : Colors.white24,
                          width: isSelected ? 1.2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (isSelected)
                                      Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: kSandBeige,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                        child: Text('위젯 ${pinOrder + 1}',
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.black,
                                                fontWeight: FontWeight.w700)),
                                      ),
                                    Flexible(
                                      child: Text(g.title,
                                          style: const TextStyle(
                                              fontSize: 15, fontWeight: FontWeight.w400)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(DateFormat('yyyy.MM.dd').format(g.date),
                                    style: const TextStyle(fontSize: 12, color: Colors.white54)),
                              ],
                            ),
                          ),
                          Text(ddayLabel(daysUntil(g.date, now)),
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w200,
                                  color: isSelected ? kSandBeige : Colors.white,
                                  height: 1)),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Colors.white38),
                            tooltip: '삭제',
                            onPressed: () => _removeGoalAt(i),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  LinearGradient _wallpaperGradient(int preset) {
    switch (preset) {
      case 1:
        return const LinearGradient(
          colors: [Color(0xFFD6CFC2), Color(0xFFB8AFA0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 2:
        return const LinearGradient(
          colors: [Color(0xFF1F242D), Color(0xFF0E1116)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        // 기본 배경: 투명도 변화를 즉시 체감할 수 있는 웜 노을 그라데이션
        return const LinearGradient(
          colors: [Color(0xFF43282E), Color(0xFF1E293B), Color(0xFF5A402A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }
}

/// 위젯 투명도 · 박스 컬러 · 텍스트 컬러 · 포인트 컬러 커스터마이징 도구 패널
class _WidgetStyleCustomizerPanel extends StatelessWidget {
  final WidgetStyle style;
  final ValueChanged<WidgetStyle> onChanged;
  final VoidCallback onSaveAndClose;

  const _WidgetStyleCustomizerPanel({
    required this.style,
    required this.onChanged,
    required this.onSaveAndClose,
  });

  @override
  Widget build(BuildContext context) {
    final pctInt = (style.opacity * 100).round();

    return Container(
      key: const Key('widgetCustomizerPanel'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kSandBeigeDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('위젯 스타일 스튜디오',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kSandBeige)),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => onChanged(WidgetStyle(
                  opacity: 0.75,
                  boxColorValue: style.wallpaperPreset == 1 ? 0xFFF5F2EB : 0xFF0A0A0A,
                  textColorValue: style.wallpaperPreset == 1 ? 0xFF1F1A17 : 0xFFFFFFFF,
                  accentColorValue: style.wallpaperPreset == 1 ? 0xFF7A5230 : 0xFFD8C3A5,
                  wallpaperPreset: style.wallpaperPreset,
                  customBoxColors: style.customBoxColors,
                  customTextColors: style.customTextColors,
                  customAccentColors: style.customAccentColors,
                )),
                child: const Text('기본값 초기화',
                    style: TextStyle(fontSize: 11, color: Colors.white54)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. 박스 배경 투명도 슬라이더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('배경 박스 불투명도 (투명도 조절)',
                  style: TextStyle(fontSize: 12, color: Colors.white70)),
              Text('$pctInt%  (투명 ${100 - pctInt}%)',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: kSandBeige)),
            ],
          ),
          Slider(
            key: const Key('opacitySlider'),
            value: style.opacity,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            activeColor: kSandBeige,
            inactiveColor: Colors.white12,
            onChanged: (v) => onChanged(style.copyWith(opacity: v)),
          ),
          const SizedBox(height: 8),

          // 2. 박스(배경) 컬러 선택 + 옵션 추가
          _ColorOptionSelectorRow(
            title: '박스(배경) 컬러',
            selectedColor: style.boxColorValue,
            presets: kDefaultBoxColors,
            customs: style.customBoxColors,
            onSelect: (c) => onChanged(style.copyWith(boxColorValue: c)),
            onAddCustom: () async {
              final added = await showAddColorDialog(context, categoryName: '박스(배경)');
              if (added != null) {
                final nextCustoms = {...style.customBoxColors, added}.toList();
                onChanged(style.copyWith(
                  boxColorValue: added,
                  customBoxColors: nextCustoms,
                ));
              }
            },
          ),
          const SizedBox(height: 14),

          // 3. 텍스트 컬러 선택 + 옵션 추가
          _ColorOptionSelectorRow(
            title: '텍스트 컬러',
            selectedColor: style.textColorValue,
            presets: kDefaultTextColors,
            customs: style.customTextColors,
            onSelect: (c) => onChanged(style.copyWith(textColorValue: c)),
            onAddCustom: () async {
              final added = await showAddColorDialog(context, categoryName: '텍스트');
              if (added != null) {
                final nextCustoms = {...style.customTextColors, added}.toList();
                onChanged(style.copyWith(
                  textColorValue: added,
                  customTextColors: nextCustoms,
                ));
              }
            },
          ),
          const SizedBox(height: 14),

          // 4. 게이지 & D-Day 포인트 컬러 선택 + 옵션 추가
          _ColorOptionSelectorRow(
            title: '게이지 · 포인트 컬러',
            selectedColor: style.accentColorValue,
            presets: kDefaultAccentColors,
            customs: style.customAccentColors,
            onSelect: (c) => onChanged(style.copyWith(accentColorValue: c)),
            onAddCustom: () async {
              final added = await showAddColorDialog(context, categoryName: '게이지 · 포인트');
              if (added != null) {
                final nextCustoms = {...style.customAccentColors, added}.toList();
                onChanged(style.copyWith(
                  accentColorValue: added,
                  customAccentColors: nextCustoms,
                ));
              }
            },
          ),
          const SizedBox(height: 16),

          // 5. 홈화면 4×1 위젯 가운데 노출 정보 옵션 선택 (명언 미노출 · 3가지 모드 전환)
          const Text('홈화면 4×1 위젯 가운데 표시 정보 (명언 대신 노출)',
              style: TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(_Home4x1WidgetPreview.kModeLabels.length, (idx) {
              final selected = style.home4x1Mode == idx;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: idx < 2 ? 6 : 0),
                  child: InkWell(
                    onTap: () => onChanged(style.copyWith(home4x1Mode: idx)),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? kSandBeige : Colors.black,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: selected ? kSandBeige : Colors.white24),
                      ),
                      child: Text(
                        _Home4x1WidgetPreview.kModeLabels[idx],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                          color: selected ? Colors.black : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),

          // 6. 스타일 저장 완료 버튼
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('saveWidgetStyleBtn'),
              style: FilledButton.styleFrom(
                backgroundColor: kSandBeige,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: onSaveAndClose,
              icon: const Icon(Icons.check, size: 18),
              label: Text(
                '스타일 저장 완료 (불투명도 $pctInt%)',
                style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorOptionSelectorRow extends StatelessWidget {
  final String title;
  final int selectedColor;
  final List<int> presets;
  final List<int> customs;
  final ValueChanged<int> onSelect;
  final VoidCallback onAddCustom;

  const _ColorOptionSelectorRow({
    required this.title,
    required this.selectedColor,
    required this.presets,
    required this.customs,
    required this.onSelect,
    required this.onAddCustom,
  });

  @override
  Widget build(BuildContext context) {
    final allColors = <int>[...presets, ...customs.where((c) => !presets.contains(c))];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            Text(
              '#${(selectedColor & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final c in allColors)
              InkWell(
                onTap: () => onSelect(c),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c == selectedColor ? kSandBeige : Colors.white30,
                      width: c == selectedColor ? 2.5 : 1,
                    ),
                  ),
                  child: c == selectedColor
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: Color(c).computeLuminance() > 0.5 ? Colors.black : Colors.white,
                        )
                      : null,
                ),
              ),
            // [+ 색상 추가] 버튼
            InkWell(
              onTap: onAddCustom,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kSandBeigeDim),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14, color: kSandBeige),
                    SizedBox(width: 2),
                    Text('옵션 추가', style: TextStyle(fontSize: 11, color: kSandBeige)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 1. 잠금화면용 위젯 디자인 (D-Day 최대 2개 동시 노출 + 투명도/컬러 커스텀 적용)
class _LockScreenWidgetPreview extends StatelessWidget {
  final double percent;
  final int age;
  final String livedLabel;
  final List<Goal> goals;
  final String quote;
  final WidgetStyle style;
  final DateTime now;

  const _LockScreenWidgetPreview({
    required this.percent,
    required this.age,
    required this.livedLabel,
    required this.goals,
    required this.quote,
    required this.style,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final g1 = goals.isNotEmpty ? goals[0] : null;
    final g2 = goals.length > 1 ? goals[1] : null;

    return Container(
      key: const Key('lockWidgetPreview'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: style.boxColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: style.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 헤더 (좁은 화면에서도 절대 줄넘침 없도록 Flexible 처리)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 12, color: style.accentColor),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text('잠금화면 위젯 (D-Day 2개)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10.5, color: style.subTextColor, letterSpacing: 0.4)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text('LIFE $livedLabel · $age/$kLifeExpectancyYears세',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10.5, color: style.accentColor, letterSpacing: 0.2)),
            ],
          ),
          const SizedBox(height: 12),

          // 중단: 왼쪽 인생 게이지(%) + 오른쪽 D-Day 2개 나란히/2열 배치
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 왼쪽: 인생 게이지 수치
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    percent.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w300,
                      color: style.textColor,
                      height: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3, left: 2),
                    child: Text('%',
                        style: TextStyle(fontSize: 13, color: style.accentColor)),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Container(width: 1, height: 34, color: style.subTextColor.withValues(alpha: 0.25)),
              const SizedBox(width: 10),

              // 오른쪽: D-Day 슬롯 2개 (1순위 · 2순위)
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _LockDdaySlot(
                        goal: g1,
                        placeholder: 'D-Day 1 미설정',
                        style: style,
                        now: now,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 1,
                      height: 28,
                      color: style.subTextColor.withValues(alpha: 0.18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _LockDdaySlot(
                        goal: g2,
                        placeholder: 'D-Day 2 추가',
                        style: style,
                        now: now,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 게이지 바
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 5,
              backgroundColor: style.subTextColor.withValues(alpha: 0.18),
              color: style.accentColor,
            ),
          ),
          const SizedBox(height: 10),

          // 하단: 명언 전문 전체 노출 (말줄임표 없음)
          Text(
            quote,
            softWrap: true,
            style: TextStyle(
              fontSize: 12,
              color: style.textColor.withValues(alpha: 0.88),
              fontWeight: FontWeight.w300,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _LockDdaySlot extends StatelessWidget {
  final Goal? goal;
  final String placeholder;
  final WidgetStyle style;
  final DateTime now;

  const _LockDdaySlot({
    required this.goal,
    required this.placeholder,
    required this.style,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    if (goal == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(placeholder,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: style.subTextColor)),
          const SizedBox(height: 2),
          Text('—',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w300, color: style.subTextColor)),
        ],
      );
    }

    final dday = ddayLabel(daysUntil(goal!.date, now));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          goal!.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: style.subTextColor),
        ),
        const SizedBox(height: 2),
        Text(
          dday,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: style.accentColor,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

/// 2. 일반 홈화면 4x1 가로 배너형 위젯 디자인 (명언 미노출 · 3가지 가운데 정보 옵션 전환 + 투명도/컬러 커스텀 적용)
class _Home4x1WidgetPreview extends StatelessWidget {
  final double percent;
  final DateTime birth;
  final String livedLabel;
  final List<Goal> goals;
  final WidgetStyle style;
  final DateTime now;
  final ValueChanged<int> onChangeMode;

  const _Home4x1WidgetPreview({
    required this.percent,
    required this.birth,
    required this.livedLabel,
    required this.goals,
    required this.style,
    required this.now,
    required this.onChangeMode,
  });

  static const List<String> kModeLabels = [
    '올해·오늘 게이지',
    '남은 날·주말',
    'D-Day 프로그레스',
  ];

  @override
  Widget build(BuildContext context) {
    final g1 = goals.isNotEmpty ? goals[0] : null;
    final dday = g1 != null ? ddayLabel(daysUntil(g1.date, now)) : 'D-DAY';
    final isLight = style.wallpaperPreset == 1;
    final mode = style.home4x1Mode.clamp(0, 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grid_view_rounded, size: 13, color: style.accentColor),
                  const SizedBox(width: 5),
                  Text('홈화면 4×1 위젯',
                      style: TextStyle(
                          fontSize: 11,
                          color: isLight ? const Color(0xFF2C221E) : Colors.white70,
                          letterSpacing: 0.6)),
                ],
              ),
              // 3가지 가운데 노출 정보 즉시 전환 칩 버튼
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: List.generate(kModeLabels.length, (idx) {
                  final selected = mode == idx;
                  return InkWell(
                    key: Key('home4x1Mode_$idx'),
                    onTap: () => onChangeMode(idx),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: selected
                            ? style.accentColor
                            : Colors.black.withValues(alpha: isLight ? 0.12 : 0.45),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? style.accentColor
                              : (isLight ? Colors.black26 : Colors.white24),
                        ),
                      ),
                      child: Text(
                        kModeLabels[idx],
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                          color: selected
                              ? (style.accentColor.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white)
                              : (isLight ? const Color(0xFF2C221E) : Colors.white70),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        Container(
          key: const Key('home4x1WidgetPreview'),
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: style.boxColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: style.borderColor),
          ),
          child: Row(
            children: [
              // 왼쪽: 인생 게이지 수치 + 바 + LIFE D+
              SizedBox(
                width: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(percent.toStringAsFixed(1),
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w300,
                                color: style.textColor,
                                height: 1)),
                        Text('%', style: TextStyle(fontSize: 10.5, color: style.accentColor)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        minHeight: 4,
                        backgroundColor: style.subTextColor.withValues(alpha: 0.18),
                        color: style.accentColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('LIFE $livedLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 9.5, letterSpacing: 0.2, color: style.accentColor)),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 46,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: style.subTextColor.withValues(alpha: 0.22),
              ),
              // 가운데: 명언 없이 3가지 미니멀 타임/목표 지표 중 선택한 모드 표시
              Expanded(
                child: _buildCenterContent(mode),
              ),
              const SizedBox(width: 10),
              // 오른쪽: 대표 D-Day 강조 (제목 + D-Day)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 76),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      g1?.title ?? '목표 미설정',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: style.subTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        dday,
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: style.accentColor,
                            height: 1.05),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCenterContent(int mode) {
    switch (mode) {
      case 1:
        // 옵션 2: 남은 인생 타임 카운트다운 (80세까지 남은 일수 · 남은 주말 횟수)
        final remDays = NumberFormat('#,###').format(remainingLifeDays(birth, now));
        final remWeekends = NumberFormat('#,###').format(remainingLifeWeekends(birth, now));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'REMAINING TIME (80세 기준)',
              style: TextStyle(
                fontSize: 9.5,
                letterSpacing: 0.8,
                color: style.subTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('남은 날', style: TextStyle(fontSize: 10, color: style.subTextColor)),
                      Text(
                        '$remDays일',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: style.textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('남은 주말', style: TextStyle(fontSize: 10, color: style.subTextColor)),
                      Text(
                        '$remWeekends회',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: style.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );

      case 2:
        // 옵션 3: D-Day 목표 프로그레스 바 (목표일까지 남은 일수 + 게이지 바 + 2순위 목표)
        final g1 = goals.isNotEmpty ? goals[0] : null;
        final g2 = goals.length > 1 ? goals[1] : null;
        final rem = g1 != null ? daysUntil(g1.date, now) : 0;
        // 1년(365일) 기준 목표 달성 임박도 게이지 (가까워질수록 100%에 수렴)
        final goalProgress = g1 == null
            ? 0.0
            : (rem <= 0 ? 1.0 : ((365 - rem.clamp(0, 365)) / 365).clamp(0.08, 1.0));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    g1 != null ? 'TARGET · ${g1.title}' : '목표를 추가해 보세요',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: style.textColor,
                    ),
                  ),
                ),
                Text(
                  g1 != null ? '${(goalProgress * 100).round()}%' : '',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: style.accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: goalProgress,
                minHeight: 5,
                backgroundColor: style.subTextColor.withValues(alpha: 0.18),
                color: style.accentColor,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              g2 != null
                  ? 'NEXT · ${g2.title} (${ddayLabel(daysUntil(g2.date, now))})'
                  : (g1 != null
                      ? '목표일: ${DateFormat('yyyy.MM.dd').format(g1.date)}'
                      : 'D-Day 달성률 바가 표시됩니다'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: style.subTextColor),
            ),
          ],
        );

      default:
        // 옵션 1 (기본 추천): 올해(YEAR) + 오늘(TODAY) 진행률 듀얼 게이지
        final yearPct = yearElapsedPercent(now);
        final todayPct = todayElapsedPercent(now);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 올해 게이지
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${now.year} YEAR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: style.subTextColor,
                  ),
                ),
                Text(
                  '${yearPct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: style.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: yearPct / 100,
                minHeight: 4,
                backgroundColor: style.subTextColor.withValues(alpha: 0.18),
                color: style.accentColor,
              ),
            ),
            const SizedBox(height: 7),
            // 오늘 하루 게이지
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TODAY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: style.subTextColor,
                  ),
                ),
                Text(
                  '${todayPct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: style.accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: todayPct / 100,
                minHeight: 4,
                backgroundColor: style.subTextColor.withValues(alpha: 0.18),
                color: style.textColor.withValues(alpha: 0.85),
              ),
            ),
          ],
        );
    }
  }
}

/// 3. iOS (iPhone WidgetKit) 전용 잠금화면 & 홈화면 위젯 미리보기 쇼케이스
class _IosWidgetKitShowcase extends StatelessWidget {
  final double percent;
  final int age;
  final String livedLabel;
  final List<Goal> goals;
  final String quote;
  final WidgetStyle style;
  final DateTime now;

  const _IosWidgetKitShowcase({
    required this.percent,
    required this.age,
    required this.livedLabel,
    required this.goals,
    required this.quote,
    required this.style,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final g1 = goals.isNotEmpty ? goals[0] : null;
    final g2 = goals.length > 1 ? goals[1] : null;
    final g1Str = g1 != null ? '${g1.title} ${ddayLabel(daysUntil(g1.date, now))}' : 'D-Day 1 미설정';
    final g2Str = g2 != null ? '${g2.title} ${ddayLabel(daysUntil(g2.date, now))}' : 'D-Day 2 추가 가능';

    return Column(
      key: const Key('iosWidgetShowcase'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // iOS 16+ 잠금화면 상단 시계 & 직사각형 위젯 (accessoryRectangular)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: style.boxColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: style.borderColor),
          ),
          child: Column(
            children: [
              // Dynamic Island 미니 모형
              Container(
                width: 78,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                DateFormat('MM월 dd일').format(now),
                style: TextStyle(
                  fontSize: 11,
                  color: style.textColor.withValues(alpha: 0.75),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                DateFormat('HH:mm').format(now),
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w600,
                  color: style.textColor,
                  height: 1.05,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              // iOS accessoryRectangular 잠금화면 위젯 박스
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: style.rawBoxColor.withValues(alpha: (style.opacity * 0.65).clamp(0.15, 0.85)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: style.accentColor.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.phone_iphone, size: 12, color: style.accentColor),
                            const SizedBox(width: 4),
                            Text(
                              'iOS 잠금화면 위젯 · ${percent.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: style.textColor,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'LIFE $livedLabel',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: style.accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        minHeight: 4,
                        backgroundColor: style.subTextColor.withValues(alpha: 0.2),
                        color: style.accentColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            g1Str,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: style.accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '· $g2Str',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: style.textColor.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // iOS systemMedium 홈화면 위젯 (22pt Squircle 라운딩)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: style.boxColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: style.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'iOS 홈화면 Medium 위젯 (WidgetKit)',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: style.accentColor),
                  ),
                  Text(
                    'LIFE $livedLabel · $age세/$kLifeExpectancyYears세',
                    style: TextStyle(fontSize: 10, color: style.subTextColor),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '${percent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      color: style.textColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _LockDdaySlot(
                      goal: g1,
                      placeholder: 'D-Day 1 미설정',
                      style: style,
                      now: now,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _LockDdaySlot(
                      goal: g2,
                      placeholder: 'D-Day 2 추가 가능',
                      style: style,
                      now: now,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                quote,
                softWrap: true,
                style: TextStyle(
                  fontSize: 11,
                  color: style.textColor.withValues(alpha: 0.88),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// D-Day 추가 팝업 다이얼로그
Future<Goal?> showGoalDialog(BuildContext context) async {
  final titleCtrl = TextEditingController();
  DateTime? pickedDate;

  return showDialog<Goal>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        final valid = titleCtrl.text.trim().isNotEmpty && pickedDate != null;
        return AlertDialog(
          backgroundColor: const Color(0xFF121212),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: Colors.white24),
          ),
          title: const Text('D-Day 추가', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('dialogGoalTitle'),
                controller: titleCtrl,
                autofocus: true,
                maxLength: 20,
                onChanged: (_) => setModalState(() {}),
                decoration: const InputDecoration(
                  labelText: '목표 제목',
                  hintText: '예: 마라톤 완주, 자격증 시험',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                key: const Key('dialogGoalDate'),
                onTap: () async {
                  final now = DateTime.now();
                  final d = await showMementoDatePicker(
                    context: ctx,
                    title: '목표 날짜 선택',
                    initialDate: pickedDate ?? now,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2200),
                  );
                  if (d != null) setModalState(() => pickedDate = d);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        pickedDate == null
                            ? '목표 날짜 선택 (이번 달 달력 열기)'
                            : DateFormat('yyyy년 MM월 dd일').format(pickedDate!),
                        style: const TextStyle(fontSize: 15),
                      ),
                      const Icon(Icons.calendar_today, size: 18, color: kSandBeige),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소', style: TextStyle(color: Colors.white54)),
            ),
            FilledButton(
              key: const Key('dialogGoalSave'),
              style: FilledButton.styleFrom(
                backgroundColor: kSandBeige,
                foregroundColor: Colors.black,
              ),
              onPressed: valid
                  ? () => Navigator.pop(ctx, Goal(titleCtrl.text.trim(), pickedDate!))
                  : null,
              child: const Text('추가', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    ),
  );
}

class _Welcome extends StatelessWidget {
  final VoidCallback onStart;
  const _Welcome({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Text('MEMENTO\nLOCK',
                  style: TextStyle(
                      fontSize: 48, fontWeight: FontWeight.w200, height: 1.1, letterSpacing: 4)),
              const SizedBox(height: 16),
              const Text('남은 시간을 기억하세요.', style: TextStyle(color: kSandBeige)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('start'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kSandBeige,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: onStart,
                  child: const Text('시작하기',
                      style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final Profile? initial;
  const SettingsPage({super.key, this.initial});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  DateTime? _birth;
  late final TextEditingController _birthCtrl;
  late List<Goal> _goals;
  late QuoteMode _quoteMode;
  String? _birthError;
  bool _showBirthKeypad = true; // 에뮬레이터/모바일에서 키보드가 안 올라와도 바로 터치 입력 가능한 내장 숫자패드

  @override
  void initState() {
    super.initState();
    _birth = widget.initial?.birth;
    _birthCtrl = TextEditingController(
      text: _birth != null ? DateFormat('yyyyMMdd').format(_birth!) : '',
    );
    _goals = [...(widget.initial?.goals ?? const <Goal>[])];
    _quoteMode = widget.initial?.quoteMode ?? QuoteMode.daily;
  }

  @override
  void dispose() {
    _birthCtrl.dispose();
    super.dispose();
  }

  void _onBirthTextChanged(String v) {
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      setState(() {
        _birth = null;
        _birthError = null;
      });
      return;
    }
    final parsed = parseBirthInput(digits);
    setState(() {
      _birth = parsed;
      _birthError = (digits.length == 8 && parsed == null)
          ? '올바른 생년월일 8자리를 입력해 주세요 (예: 19950515)'
          : null;
    });
  }

  Future<void> _pickBirthCalendar() async {
    final now = DateTime.now();
    final picked = await showMementoDatePicker(
      context: context,
      title: '생년월일 선택',
      initialDate: _birth ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _birth = picked;
        _birthCtrl.text = DateFormat('yyyyMMdd').format(picked);
        _birthError = null;
      });
    }
  }

  Future<void> _addGoal() async {
    final g = await showGoalDialog(context);
    if (g != null) {
      setState(() => _goals.add(g));
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _birth != null;
    const label = TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1);

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, title: const Text('설정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          children: [
            const Text('생년월일 (숫자 8자리 입력 또는 달력 선택)', style: label),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: TextField(
                      key: const Key('birthInput'),
                      controller: _birthCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      onChanged: _onBirthTextChanged,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w300, letterSpacing: 1.5),
                      decoration: const InputDecoration(
                        hintText: '예: 19950515',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24)),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: kSandBeige)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    key: const Key('birthCalendarBtn'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kSandBeige,
                      side: const BorderSide(color: kSandBeigeDim),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: _pickBirthCalendar,
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: const Text('달력', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _birthError ??
                  (_birth != null
                      ? '선택됨: ${DateFormat('yyyy년 MM월 dd일').format(_birth!)} (LIFE ${livedDayLabel(_birth!)})'
                      : '연도(4자리) + 월(2자리) + 일(2자리)을 입력하거나 달력/숫자패드를 누르세요'),
              style: TextStyle(
                fontSize: 12,
                color: _birthError != null ? Colors.redAccent : Colors.white54,
              ),
            ),
            const SizedBox(height: 10),
            // 가상 휴대폰/모바일에서도 100% 클릭·터치로 즉시 8자리 입력이 가능한 내장 퀵 숫자패드
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text('화면 터치 숫자 키패드',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.white54)),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: kSandBeige,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => setState(() => _showBirthKeypad = !_showBirthKeypad),
                  icon: Icon(
                    _showBirthKeypad ? Icons.keyboard_hide : Icons.dialpad,
                    size: 14,
                  ),
                  label: Text(_showBirthKeypad ? '키패드 접기' : '키패드 열기',
                      style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
            if (_showBirthKeypad) ...[
              const SizedBox(height: 6),
              _InlineBirthKeypad(
                onDigit: (d) {
                  if (_birthCtrl.text.length >= 8) return;
                  final next = '${_birthCtrl.text}$d';
                  _birthCtrl.text = next;
                  _birthCtrl.selection = TextSelection.collapsed(offset: next.length);
                  _onBirthTextChanged(next);
                },
                onBackspace: () {
                  if (_birthCtrl.text.isEmpty) return;
                  final next = _birthCtrl.text.substring(0, _birthCtrl.text.length - 1);
                  _birthCtrl.text = next;
                  _birthCtrl.selection = TextSelection.collapsed(offset: next.length);
                  _onBirthTextChanged(next);
                },
                onClear: () {
                  _birthCtrl.clear();
                  _onBirthTextChanged('');
                },
              ),
            ],
            const SizedBox(height: 32),

            // ── 명언 노출 주기 설정 ──
            const Text('명언 바뀌는 주기 (총 95선)', style: label),
            const SizedBox(height: 12),
            SegmentedButton<QuoteMode>(
              segments: const [
                ButtonSegment(
                  value: QuoteMode.daily,
                  label: Text('하루에 한 번 (추천)'),
                  icon: Icon(Icons.wb_sunny_outlined, size: 16),
                ),
                ButtonSegment(
                  value: QuoteMode.everyTime,
                  label: Text('볼 때마다 랜덤'),
                  icon: Icon(Icons.shuffle, size: 16),
                ),
              ],
              selected: {_quoteMode},
              onSelectionChanged: (s) => setState(() => _quoteMode = s.first),
            ),

            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('나의 D-DAY 목록', style: label),
                OutlinedButton.icon(
                  key: const Key('addGoalBtn'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kSandBeige,
                    side: const BorderSide(color: kSandBeigeDim),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: _addGoal,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('추가'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_goals.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text('오른쪽 위 [+ 추가] 버튼을 눌러 D-Day를 등록해 보세요.',
                      style: TextStyle(color: Colors.white54)),
                ),
              )
            else
              ...List.generate(_goals.length, (i) {
                final g = _goals[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.title, style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(DateFormat('yyyy.MM.dd').format(g.date),
                                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                        Text(ddayLabel(daysUntil(g.date)),
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w300, color: kSandBeige)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.white54),
                          onPressed: () => setState(() => _goals.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 32),
            FilledButton.icon(
              key: const Key('save'),
              style: FilledButton.styleFrom(
                backgroundColor: kSandBeige,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: valid
                  ? () => Navigator.pop(
                        context,
                        Profile(
                          _birth!,
                          _goals,
                          _quoteMode,
                          widget.initial?.widgetStyle ?? const WidgetStyle(),
                          widget.initial?.pinnedGoalIndices ?? const [0, 1],
                        ),
                      )
                  : null,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('저장 및 폰 위젯 즉시 적용',
                  style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 가상 휴대폰(에뮬레이터)이나 모바일 화면에서 마우스 클릭/터치만으로 8자리 생년월일을 빠르게 입력하는 키패드
class _InlineBirthKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const _InlineBirthKeypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['CLR', '0', 'DEL'],
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  for (final key in row)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: SizedBox(
                          height: 40,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor:
                                  key == 'CLR' || key == 'DEL' ? const Color(0xFF1E1915) : Colors.black,
                              foregroundColor:
                                  key == 'CLR' || key == 'DEL' ? kSandBeige : Colors.white,
                              side: BorderSide(
                                  color: key == 'CLR' || key == 'DEL'
                                      ? kSandBeigeDim
                                      : Colors.white24),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: () {
                              if (key == 'CLR') {
                                onClear();
                              } else if (key == 'DEL') {
                                onBackspace();
                              } else {
                                onDigit(key);
                              }
                            },
                            child: key == 'DEL'
                                ? const Icon(Icons.backspace_outlined, size: 16)
                                : Text(
                                    key == 'CLR' ? '초기화' : key,
                                    style: TextStyle(
                                      fontSize: key == 'CLR' ? 12 : 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
