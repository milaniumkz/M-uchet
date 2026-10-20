import '/auth/firebase_auth/auth_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/utils/effective_company_support.dart';
import '/utils/owner_investment_support.dart';

class PersonalFinanceSupport {
  static const String walletsCollection = 'user_wallets';
  static const String categoriesCollection = 'personal_finance_categories';
  static const String entriesCollection = 'personal_finance_entries';

  static String effectiveCompanyId(User? user) {
    return resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: user?.uid ?? '',
    );
  }

  static double toNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
  }

  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final raw = value.trim();
      if (raw.isEmpty) return null;
      if (raw.contains('.')) {
        final parts = raw.split('.');
        if (parts.length >= 3) {
          final day = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2]);
          if (day != null && month != null && year != null) {
            return DateTime(year, month, day);
          }
        }
      }
      return DateTime.tryParse(raw);
    }
    return null;
  }

  static Future<void> applyWalletDelta(
    FirebaseFirestore firestore,
    String walletId,
    double delta,
  ) async {
    if (walletId.trim().isEmpty || delta == 0) return;
    await firestore.collection(walletsCollection).doc(walletId).update({
      'balance': FieldValue.increment(delta),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  static double signedAmount(String type, double amount) {
    return type == 'income' ? amount : -amount;
  }

  static String entryTypeLabel(String type) {
    if (type == 'income') return 'Доход';
    if (type == 'investment') return ownerInvestmentDisplayLabel;
    return 'Расход';
  }

  static String buildCategoryPath(Map<String, dynamic> entry) {
    final parts = <String>[
      (entry['category_title'] ?? '').toString().trim(),
      (entry['subcategory1_title'] ?? '').toString().trim(),
      (entry['subcategory2_title'] ?? '').toString().trim(),
    ].where((element) => element.isNotEmpty).toList();
    return parts.join(' / ');
  }
}
