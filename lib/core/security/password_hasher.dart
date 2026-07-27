import 'package:crypto/crypto.dart';
import 'dart:convert';

class PasswordHasher {
  static String hash(String plainText) {
    final bytes = utf8.encode(plainText);
    return sha256.convert(bytes).toString();
  }
}
