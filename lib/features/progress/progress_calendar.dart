/// Calendar helpers for local-date navigation in Progress.
class ProgressCalendar {
  const ProgressCalendar._();

  static DateTime addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  static DateTime startOfWeek(DateTime date) =>
      addDays(date, DateTime.monday - date.weekday);
}
