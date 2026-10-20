import 'package:cloud_firestore/cloud_firestore.dart';

import '/utils/domain_entry_adapters.dart';
import '/utils/security_hash.dart';

class CashierShiftSetup {
  const CashierShiftSetup({
    required this.cashier,
    required this.cashRegisterName,
    required this.startingCash,
  });

  final CashierEntryView cashier;
  final String cashRegisterName;
  final double startingCash;
}

Future<CashierEntryView?> findCashierByPin({
  required FirebaseFirestore firestore,
  required String companyId,
  required String pin,
}) async {
  final hashedPin = hashSensitiveValue(pin);
  final snap = await firestore
      .collection('cashiers')
      .where('idCompany', isEqualTo: companyId)
      .where('pin_hash', isEqualTo: hashedPin)
      .limit(1)
      .get();
  dynamic matchedDoc = snap.docs.isNotEmpty ? snap.docs.first : null;
  if (snap.docs.isEmpty) {
    final legacySnap = await firestore
        .collection('cashiers')
        .where('idCompany', isEqualTo: companyId)
        .where('pin', isEqualTo: pin)
        .limit(1)
        .get();
    if (legacySnap.docs.isNotEmpty) {
      final legacyDoc = legacySnap.docs.first;
      await legacyDoc.reference.update({
        'pin_hash': hashedPin,
        'pin_migrated_at': FieldValue.serverTimestamp(),
        'pin': FieldValue.delete(),
      });
      matchedDoc = legacyDoc;
    }
  }
  if (matchedDoc == null) return null;
  final raw = matchedDoc.data();
  final data =
      raw is Map<String, dynamic> ? raw : Map<String, dynamic>.from(raw as Map);
  return CashierEntryView.fromMap({'id': matchedDoc.id, ...data});
}

Map<String, dynamic> buildCashShiftOpenPayload({
  required String companyId,
  required String userId,
  required String openedByUserName,
  required CashierEntryView cashier,
  required String cashRegisterName,
  required double startingCash,
  required Map<String, dynamic> openGeo,
}) {
  return {
    'idCompany': companyId,
    'user_id': userId,
    'opened_by_user_id': userId,
    'opened_by_user_name': openedByUserName,
    'cashier_id': cashier.id,
    'cashier_name': cashier.name.trim(),
    'cash_register_name': cashRegisterName.trim(),
    'shop_id': cashier.shopId.trim(),
    'shop_name': cashier.shopName.trim(),
    'status': 'open',
    'opened_at': FieldValue.serverTimestamp(),
    'opened_geo': openGeo,
    'starting_cash': startingCash,
    'cash_sales': 0,
    'card_sales': 0,
    'transactions': 0,
  };
}

Map<String, dynamic> buildStaffScheduleOpenPayload({
  required String companyId,
  required String shiftId,
  required String userId,
  required CashierEntryView cashier,
  required Map<String, dynamic> openGeo,
}) {
  return {
    'idCompany': companyId,
    'shift_id': shiftId,
    'cashier_id': cashier.id,
    'cashier_name': cashier.name.trim(),
    'shop_id': cashier.shopId.trim(),
    'shop_name': cashier.shopName.trim(),
    'status': 'open',
    'opened_at': FieldValue.serverTimestamp(),
    'opened_geo': openGeo,
    'worked_minutes': 0,
    'worked_hours': 0.0,
    'source': 'cash_mode',
    'user_id': userId,
    'created_at': FieldValue.serverTimestamp(),
    'updated_at': FieldValue.serverTimestamp(),
  };
}

Map<String, dynamic> buildCashShiftClosePatch({
  required double endingCash,
  required Map<String, dynamic> closeGeo,
  required int workedMinutes,
  required double workedHours,
}) {
  return {
    'status': 'closed',
    'closed_at': FieldValue.serverTimestamp(),
    'ending_cash': endingCash,
    'closed_geo': closeGeo,
    'worked_minutes': workedMinutes,
    'worked_hours': workedHours,
  };
}

Map<String, dynamic> buildStaffScheduleClosePayload({
  required String companyId,
  required String shiftId,
  required String cashierId,
  required String cashierName,
  required String shopId,
  required String shopName,
  required dynamic openedAt,
  required Map<String, dynamic>? openedGeo,
  required Map<String, dynamic> closeGeo,
  required int workedMinutes,
  required double workedHours,
}) {
  return {
    'idCompany': companyId,
    'shift_id': shiftId,
    'cashier_id': cashierId,
    'cashier_name': cashierName,
    'shop_id': shopId,
    'shop_name': shopName,
    'status': 'closed',
    'opened_at': openedAt,
    'closed_at': FieldValue.serverTimestamp(),
    'opened_geo': openedGeo,
    'closed_geo': closeGeo,
    'worked_minutes': workedMinutes,
    'worked_hours': workedHours,
    'source': 'cash_mode',
    'updated_at': FieldValue.serverTimestamp(),
  };
}
