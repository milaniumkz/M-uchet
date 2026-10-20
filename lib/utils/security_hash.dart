import 'dart:convert';

import 'package:crypto/crypto.dart';

String hashSensitiveValue(String value) {
  final normalized = value.trim();
  return sha256.convert(utf8.encode(normalized)).toString();
}

bool matchesSensitiveHash(String rawValue, String? storedHash) {
  if (storedHash == null || storedHash.trim().isEmpty) {
    return false;
  }
  return hashSensitiveValue(rawValue) == storedHash.trim();
}
