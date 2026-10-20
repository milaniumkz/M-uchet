import 'package:collection/collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import '/flutter_flow/flutter_flow_util.dart';

class DebtPaymentLinkRecord extends FirestoreRecord {
  DebtPaymentLinkRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  String? _debtId;
  String get debtId => _debtId ?? '';

  String? _paymentTransactionId;
  String get paymentTransactionId => _paymentTransactionId ?? '';

  double? _amount;
  double get amount => _amount ?? 0;

  String? _ledgerScope;
  String get ledgerScope => _ledgerScope ?? '';

  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;

  void _initializeFields() {
    _debtId = (snapshotData['debt_id'] ?? snapshotData['debtId']) as String?;
    _paymentTransactionId = (snapshotData['payment_transaction_id'] ??
        snapshotData['paymentTransactionId']) as String?;
    _amount = (snapshotData['amount'] as num?)?.toDouble();
    _ledgerScope = (snapshotData['ledger_scope'] ?? snapshotData['ledgerScope'])
        as String?;
    _createdAt = snapshotData['created_at'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('debt_payment_links');

  static DebtPaymentLinkRecord fromSnapshot(DocumentSnapshot snapshot) =>
      DebtPaymentLinkRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );
}

Map<String, dynamic> createDebtPaymentLinkRecordData({
  String? debtId,
  String? paymentTransactionId,
  double? amount,
  String? ledgerScope,
  DateTime? createdAt,
  String? idCompany,
}) {
  return mapToFirestore(
    <String, dynamic>{
      'debt_id': debtId,
      'payment_transaction_id': paymentTransactionId,
      'amount': amount,
      'ledger_scope': ledgerScope,
      'created_at': createdAt,
      'idCompany': idCompany,
    }.withoutNulls,
  );
}

class DebtPaymentLinkRecordDocumentEquality
    implements Equality<DebtPaymentLinkRecord> {
  const DebtPaymentLinkRecordDocumentEquality();

  @override
  bool equals(DebtPaymentLinkRecord? e1, DebtPaymentLinkRecord? e2) =>
      e1?.debtId == e2?.debtId &&
      e1?.paymentTransactionId == e2?.paymentTransactionId &&
      e1?.amount == e2?.amount;

  @override
  int hash(DebtPaymentLinkRecord? e) => const ListEquality().hash(
        [e?.debtId, e?.paymentTransactionId, e?.amount],
      );

  @override
  bool isValidKey(Object? o) => o is DebtPaymentLinkRecord;
}
