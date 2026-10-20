import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/utils/accounting_accounts.dart';
import '/utils/ledger_scope.dart';

class ShetaRecord extends FirestoreRecord {
  ShetaRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "tip" field.
  String? _tip;
  String get tip => _tip ?? '';
  bool hasTip() => _tip != null;

  // "coment" field.
  String? _coment;
  String get coment => _coment ?? '';
  bool hasComent() => _coment != null;

  // "summa" field.
  double? _summa;
  double get summa => _summa ?? 0.0;
  bool hasSumma() => _summa != null;

  // "currency" field.
  String? _currency;
  String get currency => _currency ?? accountCurrency;
  bool hasCurrency() => _currency != null;

  // "account_currency" field.
  String? _accountCurrency;
  String get accountCurrency => _accountCurrency ?? 'KZT';
  bool hasAccountCurrency() => _accountCurrency != null;

  // "company_currency" field.
  String? _companyCurrency;
  String get companyCurrency => _companyCurrency ?? 'KZT';
  bool hasCompanyCurrency() => _companyCurrency != null;

  // "dateCreate" field.
  DateTime? _dateCreate;
  DateTime? get dateCreate => _dateCreate;
  bool hasDateCreate() => _dateCreate != null;

  // "idCompany" field.
  String? _idCompany;
  String get idCompany => _idCompany ?? '';
  bool hasIdCompany() => _idCompany != null;

  // "typeUchet" field.
  String? _typeUchet;
  String get typeUchet => _typeUchet ?? '';
  bool hasTypeUchet() => _typeUchet != null;

  // "ledger_scope" field.
  String? _ledgerScope;
  String get ledgerScope => _ledgerScope ?? '';
  bool hasLedgerScope() => _ledgerScope != null;
  LedgerScope get ledgerScopeEnum => ledgerScopeFromLegacyValue(
        _ledgerScope?.isNotEmpty == true ? _ledgerScope : _typeUchet,
      );

  // "opening_balance" field.
  double? _openingBalance;
  double get openingBalance => _openingBalance ?? 0.0;
  bool hasOpeningBalance() => _openingBalance != null;

  // "opening_balance_date" field.
  DateTime? _openingBalanceDate;
  DateTime? get openingBalanceDate => _openingBalanceDate;
  bool hasOpeningBalanceDate() => _openingBalanceDate != null;

  // "account_type" field.
  String? _accountType;
  String get accountType => _accountType ?? '';
  bool hasAccountType() => _accountType != null;
  AccountNature get accountNature =>
      accountNatureFromValue(_accountType, tip: _tip);

  // "debit_turnover" field.
  double? _debitTurnover;
  double get debitTurnover => _debitTurnover ?? 0.0;
  bool hasDebitTurnover() => _debitTurnover != null;

  // "credit_turnover" field.
  double? _creditTurnover;
  double get creditTurnover => _creditTurnover ?? 0.0;
  bool hasCreditTurnover() => _creditTurnover != null;

  void _initializeFields() {
    _title = snapshotData['title'] as String?;
    _tip = snapshotData['tip'] as String?;
    _coment = snapshotData['coment'] as String?;
    _summa = castToType<double>(snapshotData['summa']);
    _currency = snapshotData['currency'] as String?;
    _accountCurrency = (snapshotData['account_currency'] ??
        snapshotData['accountCurrency']) as String?;
    _companyCurrency = (snapshotData['company_currency'] ??
        snapshotData['companyCurrency']) as String?;
    _dateCreate = snapshotData['dateCreate'] as DateTime?;
    _idCompany = snapshotData['idCompany'] as String?;
    _typeUchet = snapshotData['typeUchet'] as String?;
    _ledgerScope = (snapshotData['ledger_scope'] ?? snapshotData['ledgerScope'])
        as String?;
    _openingBalance = castToType<double>(
      snapshotData['opening_balance'] ?? snapshotData['openingBalance'],
    );
    _openingBalanceDate = _asDateTime(
      snapshotData['opening_balance_date'] ??
          snapshotData['openingBalanceDate'],
    );
    _accountType = (snapshotData['account_type'] ?? snapshotData['accountType'])
        as String?;
    _debitTurnover = castToType<double>(snapshotData['debit_turnover']);
    _creditTurnover = castToType<double>(snapshotData['credit_turnover']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('sheta');

  static Stream<ShetaRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ShetaRecord.fromSnapshot(s));

  static Future<ShetaRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ShetaRecord.fromSnapshot(s));

  static ShetaRecord fromSnapshot(DocumentSnapshot snapshot) => ShetaRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );

  static ShetaRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ShetaRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ShetaRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ShetaRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createShetaRecordData({
  String? title,
  String? tip,
  String? coment,
  double? summa,
  String? currency,
  String? accountCurrency,
  String? companyCurrency,
  DateTime? dateCreate,
  String? idCompany,
  String? typeUchet,
  String? ledgerScope,
  double? openingBalance,
  DateTime? openingBalanceDate,
  String? accountType,
  double? debitTurnover,
  double? creditTurnover,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'title': title,
      'tip': tip,
      'coment': coment,
      'summa': summa,
      'currency': currency ?? accountCurrency,
      'account_currency': accountCurrency ?? currency,
      'accountCurrency': accountCurrency ?? currency,
      'company_currency': companyCurrency,
      'companyCurrency': companyCurrency,
      'dateCreate': dateCreate,
      'idCompany': idCompany,
      'typeUchet': typeUchet,
      'ledger_scope':
          ledgerScope ?? ledgerScopeFromLegacyValue(typeUchet).storageValue,
      'ledgerScope':
          ledgerScope ?? ledgerScopeFromLegacyValue(typeUchet).storageValue,
      'opening_balance': openingBalance,
      'openingBalance': openingBalance,
      'opening_balance_date': openingBalanceDate,
      'openingBalanceDate': openingBalanceDate,
      'account_type': accountType,
      'accountType': accountType,
      'debit_turnover': debitTurnover,
      'credit_turnover': creditTurnover,
    }.withoutNulls,
  );

  return firestoreData;
}

class ShetaRecordDocumentEquality implements Equality<ShetaRecord> {
  const ShetaRecordDocumentEquality();

  @override
  bool equals(ShetaRecord? e1, ShetaRecord? e2) {
    return e1?.title == e2?.title &&
        e1?.tip == e2?.tip &&
        e1?.coment == e2?.coment &&
        e1?.summa == e2?.summa &&
        e1?.currency == e2?.currency &&
        e1?.accountCurrency == e2?.accountCurrency &&
        e1?.companyCurrency == e2?.companyCurrency &&
        e1?.dateCreate == e2?.dateCreate &&
        e1?.idCompany == e2?.idCompany &&
        e1?.typeUchet == e2?.typeUchet &&
        e1?.ledgerScope == e2?.ledgerScope &&
        e1?.openingBalance == e2?.openingBalance &&
        e1?.openingBalanceDate == e2?.openingBalanceDate &&
        e1?.accountType == e2?.accountType &&
        e1?.debitTurnover == e2?.debitTurnover &&
        e1?.creditTurnover == e2?.creditTurnover;
  }

  @override
  int hash(ShetaRecord? e) => const ListEquality().hash([
        e?.title,
        e?.tip,
        e?.coment,
        e?.summa,
        e?.currency,
        e?.accountCurrency,
        e?.companyCurrency,
        e?.dateCreate,
        e?.idCompany,
        e?.typeUchet,
        e?.ledgerScope,
        e?.openingBalance,
        e?.openingBalanceDate,
        e?.accountType,
        e?.debitTurnover,
        e?.creditTurnover,
      ]);

  @override
  bool isValidKey(Object? o) => o is ShetaRecord;
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}
