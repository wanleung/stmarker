import 'package:flutter_test/flutter_test.dart';
import 'package:stmarker/ui/format_timestamp.dart';

void main() {
  test('includes hours once media duration exceeds one hour', () {
    expect(formatDisplayTimestamp(3900123), '01:05:00.123');
    expect(formatDisplayTimestamp(3900123, includeMillis: false), '01:05:00');
  });

  test('keeps compact minute format below one hour', () {
    expect(formatDisplayTimestamp(92100), '01:32.100');
    expect(formatDisplayTimestamp(null), '—');
  });
}
