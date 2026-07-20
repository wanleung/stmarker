import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/karaoke/karaoke_models.dart';

void main() {
  test('pre-display durations expose only timed lead values', () {
    expect(KaraokePreDisplay.off.leadMs, isNull);
    expect(KaraokePreDisplay.seconds3.leadMs, 3000);
    expect(KaraokePreDisplay.seconds4.leadMs, 4000);
    expect(KaraokePreDisplay.seconds5.leadMs, 5000);
    expect(KaraokePreDisplay.oneLineAhead.leadMs, isNull);
  });

  test('karaoke marks have value equality and JSON round trip', () {
    const mark = KaraokeMark(unitText: 'hello', startMs: 1000);

    expect(KaraokeMark.fromJson(mark.toJson()), mark);
    expect(
      const KaraokeMark(unitText: 'hello', startMs: 1000).hashCode,
      mark.hashCode,
    );
  });
}
