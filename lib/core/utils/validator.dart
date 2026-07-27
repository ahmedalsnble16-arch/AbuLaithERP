class Validator {
  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) return 'مطلوب';
    return null;
  }

  static String? positiveNumber(String? value) {
    final number = double.tryParse(value ?? '');
    if (number == null || number < 0) return 'رقم غير صحيح';
    return null;
  }
}
