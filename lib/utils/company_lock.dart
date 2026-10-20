import '/auth/firebase_auth/auth_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyLock {
  static final Map<String, _CacheEntry> _cache = {};
  static const Duration _ttl = Duration(seconds: 30);

  static void invalidate(String companyId) {
    _cache.remove(companyId);
  }

  static Future<bool> isLocked(String companyId) async {
    return false;
  }

  static Future<bool> isLockedForCurrentUser() async {
    return false;
  }
}

class _CacheEntry {
  final bool locked;
  final DateTime at;
  _CacheEntry(this.locked, this.at);
}
