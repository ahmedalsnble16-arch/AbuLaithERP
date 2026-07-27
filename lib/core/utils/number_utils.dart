class NumberUtils {
  static double parseDouble(String value) {
    return double.tryParse(value) ?? 0;
  }

  static int parseInt(String value) {
    return int.tryParse(value) ?? 0;
  }
}
