import 'package:collection/collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import '/flutter_flow/flutter_flow_util.dart';

class DebtRecord extends FirestoreRecord {
  DebtRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  String? _type;
  String get type => _type ?? '';

  String? _counterpartyId;
  String get counterpartyId => _counterpartyId ?? '';

  String? _counterpartyName;
  String get counterpartyName => _counterpartyName ?? '';

  String? _sourceDocumentId;
  String get sourceDocumentId => _sourceDocumentId ?? '';

  String? _sourceType;
  String get sourceType => _sourceType ?? '';

  double? _totalAmount;
  double get totalAmount => _totalAmount ?? 0;

  double? _remainingAmount;
  double get remainingAmount => _remainingAmount ?? 0;

  String? _currency;
  String get currency => _currency ?? 'KZT';

  String? _ledgerScope;
  String get ledgerScope => _ledgerScope ?? '';

  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;

  DateTime? _dueDate;
  DateTime? get dueDate => _dueDate;

  String? _status;
  String get status => _status ?? '';

  double? _creditLimit;
  double get creditLimit => _creditLimit ?? 0;

  void _initializeFields() {
    _type = snapshotData['type'] as String?;
    _counterpartyId = (snapshotData['counterparty_id'] ??
        snapshotData['counterpartyId']) as String?;
    _counterpartyName = (snapshotData['counterparty_name'] ??
        snapshotData['counterpartyName']) as String?;
    _sourceDocumentId = (snapshotData['source_document_id'] ??
        snapshotData['sourceDocumentId']) as String?;
    _sourceType =
        (snapshotData['source_type'] ?? snapshotData['sourceType']) as String?;
    _totalAmount = castToType<double>(snapshotData['total_amount']);
    _remainingAmount = castToType<double>(snapshotData['remaining_amount']);
    _currency = snapshotData['currency'] as String?;
    _ledgerScope = (snapshotData['ledger_scope'] ?? snapshotData['ledgerScope'])
        as String?;
    _createdAt = snapshotData['created_at'] as DateTime?;
    _dueDate = snapshotData['due_date'] as DateTime?;
    _status = snapshotData['status'] as String?;
    _creditLimit = castToType<double>(snapshotData['credit_limit']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('debt_register');

  static Stream<DebtRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => DebtRecord.fromSnapshot(s));

  static Future<DebtRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => DebtRecord.fromSnapshot(s));

  static DebtRecord fromSnapshot(DocumentSnapshot snapshot) => DebtRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );
}

Map<String, dynamic> createDebtRecordData({
  String? type,
  String? counterpartyId,
  String? counterpartyName,
  String? sourceDocumentId,
  String? sourceType,
  double? totalAmount,
  double? remainingAmount,
  String? currency,
  String? ledgerScope,
  DateTime? createdAt,
  DateTime? dueDate,
  String? status,
  double? creditLimit,
  String? idCompany,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'type': type,
      'counterparty_id': counterpartyId,
      'counterparty_name': counterpartyName,
      'source_document_id': sourceDocumentId,
      'source_type': sourceType,
      'total_amount': totalAmount,
      'remaining_amount': remainingAmount,
      'currency': currency,
      'ledger_scope': ledgerScope,
      'created_at': createdAt,
      'due_date': dueDate,
      'status': status,
      'credit_limit': creditLimit,
      'idCompany': idCompany,
    }.withoutNulls,
  );
  return firestoreData;
}

class DebtRecordDocumentEquality implements Equality<DebtRecord> {
  const DebtRecordDocumentEquality();

  @override
  bool equals(DebtRecord? e1, DebtRecord? e2) =>
      e1?.type == e2?.type &&
      e1?.counterpartyId == e2?.counterpartyId &&
      e1?.sourceDocumentId == e2?.sourceDocumentId &&
      e1?.remainingAmount == e2?.remainingAmount &&
      e1?.status == e2?.status;

  @override
  int hash(DebtRecord? e) => const ListEquality().hash(
        [
          e?.type,
          e?.counterpartyId,
          e?.sourceDocumentId,
          e?.remainingAmount,
          e?.status,
        ],
      );

  @override
  bool isValidKey(Object? o) => o is DebtRecord;
}
