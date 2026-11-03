import 'package:flutter_test/flutter_test.dart';
import 'package:memento_lock/main.dart';

void main() {
  test('80세 기준 인생 게이지 및 LIFE D+ 계산', () {
    expect(lifePercent(DateTime(2000, 1, 1), DateTime(2040, 1, 1)), 50);
    expect(lifePercent(DateTime(2000, 1, 1), DateTime(2100, 1, 1)), 100);
    expect(daysLived(DateTime(2026, 1, 1), DateTime(2026, 1, 11)), 10);
    expect(livedDayLabel(DateTime(2020, 1, 1), DateTime(2022, 9, 28)), 'D+1,001');
  });

  test('생년월일 숫자 8자리 파싱 및 HEX 컬러 파싱', () {
    expect(parseBirthInput('19950515'), DateTime(1995, 5, 15));
    expect(parseBirthInput('1995-05-15'), DateTime(1995, 5, 15));
    expect(parseBirthInput('19950230'), isNull);
    expect(parseHexColor('#D8C3A5'), 0xFFD8C3A5);
    expect(parseHexColor('ffffff'), 0xFFFFFFFF);
    expect(parseHexColor('GGGGGG'), isNull);
  });

  test('목표 D-Day 계산 및 위젯 스타일 직렬화', () {
    expect(daysUntil(DateTime(2026, 1, 11), DateTime(2026, 1, 1)), 10);
    expect(ddayLabel(10), 'D-10');
    const ws = WidgetStyle(opacity: 0.4, boxColorValue: 0xFF112233, customBoxColors: [0xFFABCDEF]);
    final restored = WidgetStyle.fromJson(ws.toJson());
    expect(restored.opacity, 0.4);
    expect(restored.boxColorValue, 0xFF112233);
    expect(restored.customBoxColors, [0xFFABCDEF]);
  });

  test('명언 95선 및 노출 모드 동작', () {
    expect(kQuotes.length, 95);
    final q1 = pickQuote(QuoteMode.daily, now: DateTime(2026, 11, 2));
    final q2 = pickQuote(QuoteMode.daily, now: DateTime(2026, 11, 2));
    expect(q1, q2);
  });
}
