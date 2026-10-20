import '/auth/firebase_auth/auth_util.dart';
import '/utils/effective_company_support.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogService {
  const AuditLogService._();

  static Future<void> logAction({
    required String companyId,
    required String action,
    required String entity,
    String entityId = '',
    String entityTitle = '',
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
    Map<String, dynamic>? details,
  }) async {
    final cid = companyId.trim().isNotEmpty
        ? companyId.trim()
        : resolveEffectiveCompanyId(
            userData: currentUserDocument?.snapshotData,
            fallbackUserId: currentUserUid,
          );
    if (cid.isEmpty || currentUserUid.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('activity_log').add({
        'idCompany': cid,
        'action': action,
        'entity': entity,
        'entity_id': entityId.trim(),
        'entity_title': entityTitle.trim(),
        'user_id': currentUserUid,
        'user_name': currentUserDocument?.displayName ??
            (currentUserDisplayName.trim().isNotEmpty
                ? currentUserDisplayName
                : currentUserEmail),
        'user_phone': (currentUserDocument?.snapshotData['phone_number'] ?? '')
            .toString(),
        'before': _cleanMap(before),
        'after': _cleanMap(after),
        'details': _cleanMap(details),
        'source': 'client',
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Audit must not block the business operation.
    }
  }

  static Map<String, dynamic> _cleanMap(Map<String, dynamic>? value) {
    if (value == null || value.isEmpty) return const {};
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;
      final lower = key.toLowerCase();
      if (lower.contains('password') ||
          lower.contains('pin') ||
          lower.contains('token') ||
          lower.contains('secret')) {
        continue;
      }
      result[key] = _cleanValue(entry.value);
    }
    return result;
  }

  static dynamic _cleanValue(dynamic value) {
    if (value is DocumentReference) return value.path;
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is Map) {
      return _cleanMap(value.map((key, val) => MapEntry('$key', val)));
    }
    if (value is Iterable) return value.map(_cleanValue).toList();
    return value;
  }
}
