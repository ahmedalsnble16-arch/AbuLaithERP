class DateUtils {
  static String today() {
    return DateTime.now().toIso8601String().substring(0, 10);
  }

  static String now() {
    return DateTime.now().toIso8601String();
  }

  static String format(String isoDate) {
    if (isoDate.length >= 10) {
      return isoDate.substring(0, 10);
    }
    return isoDate;
  }
}
