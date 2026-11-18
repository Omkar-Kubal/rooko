import 'package:flutter_test/flutter_test.dart';
import 'package:rooko/features/progress/progress_calendar.dart';

void main() {
  test('moves week dates by calendar fields across month boundaries', () {
    final sunday = DateTime(2026, 3, 8);
    final monday = ProgressCalendar.startOfWeek(sunday);

    expect(monday, DateTime(2026, 3, 2));
    expect(ProgressCalendar.addDays(monday, 6), DateTime(2026, 3, 8));
    expect(ProgressCalendar.addDays(monday, 7), DateTime(2026, 3, 9));
  });
}
