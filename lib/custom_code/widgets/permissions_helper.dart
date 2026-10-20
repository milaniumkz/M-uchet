import '/auth/firebase_auth/auth_util.dart';
import 'package:flutter/material.dart';
import '/utils/access_rules.dart';

class PermissionsHelper {
  static const bool openAllByDefault = false;

  static bool has(String key) {
    if (openAllByDefault) return true;
    final user = currentUserDocument;
    if (user == null) return false;
    return AccessRules.hasPermission(
      data: user.snapshotData,
      permissionKey: key,
    );
  }

  static Widget noAccess() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.lock_outline, size: 40, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text(
              'Нет доступа',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            Text(
              'Обратитесь к администратору для выдачи прав.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}
