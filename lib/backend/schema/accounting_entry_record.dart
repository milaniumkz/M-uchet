import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_flow_type.dart';

import 'index.dart';

class AccountingEntryRecord extends FirestoreRecord {
  AccountingEntryRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  String? _transactionId;
  String get transactionId => _transactionId ?? '';

  String? _sourceType;
  String get sourceType => _sourceType ?? '';

  String? _sourceId;
  String get sourceId => _sourceId ?? '';

  DateTime? _entryDate;
  DateTime? get entryDate => _entryDate;

  String? _debitAccountId;
  String get debitAccountId => _debitAccountId ?? '';

  DocumentReference? _debitSchetRef;
  DocumentReference? get debitSchetRef => _debitSchetRef;

  String? _debitAccountTitle;
  String get debitAccountTitle => _debitAccountTitle ?? '';

  String? _creditAccountId;
  String get creditAccountId => _creditAccountId ?? '';

  DocumentReference? _creditSchetRef;
  DocumentReference? get creditSchetRef => _creditSchetRef;

  String? _creditAccountTitle;
  String get creditAccountTitle => _creditAccountTitle ?? '';

  double? _amount;
  double get amount => _amount ?? 0.0;

  String? _currency;
  String get currency => _currency ?? '';

  String? _ledgerScope;
  String get ledgerScope => _ledgerScope ?? '';
  LedgerScope get ledgerScopeEnum => ledgerScopeFromLegacyValue(_ledgerScope);

  String? _moneyFlowType;
  String get moneyFlowType => _moneyFlowType ?? '';
  MoneyFlowType get moneyFlowTypeEnum => moneyFlowTypeFromValue(_moneyFlowType);

  String? _description;
  String get description => _description ?? '';

  String? _memo;
  String get memo => _memo ?? '';

  String? _taxKind;
  String get taxKind => _taxKind ?? '';

  bool? _taxable;
  bool get taxable => _taxable ?? false;

  bool? _deductible;
  bool get deductible => _deductible ?? false;

  double? _taxRate;
  double get taxRate => _taxRate ?? 0.0;

  double? _taxAmount;
  double get taxAmount => _taxAmount ?? 0.0;

  String? _idCompany;
  String get idCompany => _idCompany ?? '';

  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;

  void _initializeFields() {
    _transactionId = _asString(snapshotData['transaction_id']);
    _sourceType = _asString(snapshotData['source_type']);
    _sourceId = _asString(snapshotData['source_id']);
    _entryDate = _asDateTime(snapshotData['entry_date']);
    _debitAccountId = _asString(snapshotData['debit_account_id']);
    _debitSchetRef = _asDocumentReference(snapshotData['debit_schet_ref']);
    _debitAccountTitle = _asString(snapshotData['debit_account_title']);
    _creditAccountId = _asString(snapshotData['credit_account_id']);
    _creditSchetRef = _asDocumentReference(snapshotData['credit_schet_ref']);
    _creditAccountTitle = _asString(snapshotData['credit_account_title']);
    _amount = _asDouble(snapshotData['amount']);
    _currency = _asString(snapshotData['currency']);
    _ledgerScope = _asString(
      snapshotData['ledger_scope'] ?? snapshotData['ledgerScope'],
    );
    _moneyFlowType = _asString(
      snapshotData['money_flow_type'] ?? snapshotData['moneyFlowType'],
    );
    _description = _asString(snapshotData['description']);
    _memo = _asString(snapshotData['memo']);
    _taxKind = _asString(snapshotData['tax_kind']);
    _taxable = _asBool(
      snapshotData['taxable'] ?? snapshotData['taxable_income'],
    );
    _deductible = _asBool(
      snapshotData['deductible'] ?? snapshotData['tax_deductible'],
    );
    _taxRate = _asDouble(snapshotData['tax_rate']);
    _taxAmount = _asDouble(snapshotData['tax_amount']);
    _idCompany = _asString(snapshotData['idCompany']);
    _createdAt = _asDateTime(snapshotData['created_at']);
    _updatedAt = _asDateTime(snapshotData['updated_at']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('accounting_entries');

  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.trim().replaceAll(' ', '').replaceAll(',', '.');
      return double.tryParse(normalized);
    }
    return null;
  }

  static bool? _asBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
    return null;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static DocumentReference? _asDocumentReference(dynamic value) {
    return value is DocumentReference ? value : null;
  }

  static Stream<AccountingEntryRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => AccountingEntryRecord.fromSnapshot(s));

  static Future<AccountingEntryRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => AccountingEntryRecord.fromSnapshot(s));

  static AccountingEntryRecord fromSnapshot(DocumentSnapshot snapshot) =>
      AccountingEntryRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );

  static AccountingEntryRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      AccountingEntryRecord._(reference, mapFromFirestore(data));
}

void validateAccountingEntryPayload(Map<String, dynamic> payload) {
  final debitAccountId = (payload['debit_account_id'] ?? '').toString().trim();
  final creditAccountId =
      (payload['credit_account_id'] ?? '').toString().trim();
  final amount = castToType<double>(payload['amount']) ??
      (payload['amount'] is num ? (payload['amount'] as num).toDouble() : 0.0);
  if (debitAccountId.isEmpty || creditAccountId.isEmpty) {
    throw ArgumentError('Debit and credit accounts are required');
  }
  if (amount <= 0) {
    throw ArgumentError('Accounting entry amount must be greater than zero');
  }
}

Map<String, dynamic> createAccountingEntryRecordData({
  required String transactionId,
  required String sourceType,
  required String sourceId,
  required dynamic entryDate,
  required String debitAccountId,
  DocumentReference? debitSchetRef,
  String? debitAccountTitle,
  required String creditAccountId,
  DocumentReference? creditSchetRef,
  String? creditAccountTitle,
  required double amount,
  String? currency,
  required String ledgerScope,
  String? moneyFlowType,
  String? description,
  String? memo,
  String? taxKind,
  bool? taxable,
  bool? deductible,
  double? taxRate,
  double? taxAmount,
  required String idCompany,
  dynamic createdAt,
  dynamic updatedAt,
}) {
  final data = mapToFirestore(
    <String, dynamic>{
      'transaction_id': transactionId,
      'source_type': sourceType,
      'source_id': sourceId,
      'entry_date': entryDate,
      'debit_account_id': debitAccountId,
      'debit_schet_ref': debitSchetRef,
      'debit_account_title': debitAccountTitle,
      'credit_account_id': creditAccountId,
      'credit_schet_ref': creditSchetRef,
      'credit_account_title': creditAccountTitle,
      'amount': amount,
      'currency': currency,
      'ledger_scope': ledgerScope,
      'ledgerScope': ledgerScope,
      'money_flow_type': moneyFlowType,
      'moneyFlowType': moneyFlowType,
      'description': description,
      'memo': memo,
      'tax_kind': taxKind,
      'taxable': taxable,
      'taxable_income': taxable,
      'deductible': deductible,
      'tax_deductible': deductible,
      'tax_rate': taxRate,
      'tax_amount': taxAmount,
      'idCompany': idCompany,
      'created_at': createdAt,
      'updated_at': updatedAt,
    }.withoutNulls,
  );
  validateAccountingEntryPayload(data);
  return data;
}

class AccountingEntryRecordDocumentEquality
    implements Equality<AccountingEntryRecord> {
  const AccountingEntryRecordDocumentEquality();

  @override
  bool equals(AccountingEntryRecord? e1, AccountingEntryRecord? e2) {
    return e1?.transactionId == e2?.transactionId &&
        e1?.sourceType == e2?.sourceType &&
        e1?.sourceId == e2?.sourceId &&
        e1?.entryDate == e2?.entryDate &&
        e1?.debitAccountId == e2?.debitAccountId &&
        e1?.debitSchetRef == e2?.debitSchetRef &&
        e1?.creditAccountId == e2?.creditAccountId &&
        e1?.creditSchetRef == e2?.creditSchetRef &&
        e1?.amount == e2?.amount &&
        e1?.currency == e2?.currency &&
        e1?.ledgerScope == e2?.ledgerScope &&
        e1?.moneyFlowType == e2?.moneyFlowType &&
        e1?.description == e2?.description &&
        e1?.memo == e2?.memo &&
        e1?.taxKind == e2?.taxKind &&
        e1?.taxRate == e2?.taxRate &&
        e1?.taxAmount == e2?.taxAmount &&
        e1?.idCompany == e2?.idCompany;
  }

  @override
  int hash(AccountingEntryRecord? e) => const ListEquality().hash([
        e?.transactionId,
        e?.sourceType,
        e?.sourceId,
        e?.entryDate,
        e?.debitAccountId,
        e?.debitSchetRef,
        e?.creditAccountId,
        e?.creditSchetRef,
        e?.amount,
        e?.currency,
        e?.ledgerScope,
        e?.moneyFlowType,
        e?.description,
        e?.memo,
        e?.taxKind,
        e?.taxRate,
        e?.taxAmount,
        e?.idCompany,
      ]);

  @override
  bool isValidKey(Object? o) => o is AccountingEntryRecord;
}
