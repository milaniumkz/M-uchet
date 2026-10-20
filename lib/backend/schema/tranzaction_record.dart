import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_flow_type.dart';

class TranzactionRecord extends FirestoreRecord {
  TranzactionRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  // "type" field.
  String? _type;
  String get type => _type ?? '';
  bool hasType() => _type != null;

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

  // "kat" field.
  String? _kat;
  String get kat => _kat ?? '';
  bool hasKat() => _kat != null;

  // "text" field.
  String? _text;
  String get text => _text ?? '';
  bool hasText() => _text != null;

  // "comment" field.
  String? _comment;
  String get comment => _comment ?? '';
  bool hasComment() => _comment != null;

  // "payment_period" field.
  String? _paymentPeriod;
  String get paymentPeriod => _paymentPeriod ?? '';
  bool hasPaymentPeriod() => _paymentPeriod != null;

  // "summa" field.
  double? _summa;
  double get summa => _summa ?? 0.0;
  bool hasSumma() => _summa != null;

  // "amount_company" field.
  double? _amountCompany;
  double get amountCompany => _amountCompany ?? summa;
  bool hasAmountCompany() => _amountCompany != null;

  // "amount_original" field.
  double? _amountOriginal;
  double get amountOriginal => _amountOriginal ?? summa;
  bool hasAmountOriginal() => _amountOriginal != null;

  // "currency_original" field.
  String? _currencyOriginal;
  String get currencyOriginal => _currencyOriginal ?? companyCurrency;
  bool hasCurrencyOriginal() => _currencyOriginal != null;

  // "company_currency" field.
  String? _companyCurrency;
  String get companyCurrency => _companyCurrency ?? 'KZT';
  bool hasCompanyCurrency() => _companyCurrency != null;

  // "exchange_rate_to_company" field.
  double? _exchangeRateToCompany;
  double get exchangeRateToCompany => _exchangeRateToCompany ?? 1.0;
  bool hasExchangeRateToCompany() => _exchangeRateToCompany != null;

  // "exchange_rate_date" field.
  DateTime? _exchangeRateDate;
  DateTime? get exchangeRateDate => _exchangeRateDate;
  bool hasExchangeRateDate() => _exchangeRateDate != null;

  // "exchange_rate_source" field.
  String? _exchangeRateSource;
  String get exchangeRateSource => _exchangeRateSource ?? '';
  bool hasExchangeRateSource() => _exchangeRateSource != null;

  // "tax_rate" field.
  double? _taxRate;
  double get taxRate => _taxRate ?? 0.0;
  bool hasTaxRate() => _taxRate != null;

  // "tax_profile_country" field.
  String? _taxProfileCountry;
  String get taxProfileCountry => _taxProfileCountry ?? '';
  bool hasTaxProfileCountry() => _taxProfileCountry != null;

  // "tax_profile_version" field.
  String? _taxProfileVersion;
  String get taxProfileVersion => _taxProfileVersion ?? '';
  bool hasTaxProfileVersion() => _taxProfileVersion != null;

  // "nds" field.
  bool? _nds;
  bool get nds => _nds ?? false;
  bool hasNds() => _nds != null;

  // "summaNds" field.
  double? _summaNds;
  double get summaNds => _summaNds ?? 0.0;
  bool hasSummaNds() => _summaNds != null;

  // "taxable" field.
  bool? _taxable;
  bool get taxable => _taxable ?? false;
  bool hasTaxable() => _taxable != null;

  // "deductible" field.
  bool? _deductible;
  bool get deductible => _deductible ?? false;
  bool hasDeductible() => _deductible != null;

  // "exclude_from_company_income" field.
  bool? _excludeFromCompanyIncome;
  bool get excludeFromCompanyIncome => _excludeFromCompanyIncome ?? false;
  bool hasExcludeFromCompanyIncome() => _excludeFromCompanyIncome != null;

  // "idCompany" field.
  String? _idCompany;
  String get idCompany => _idCompany ?? '';
  bool hasIdCompany() => _idCompany != null;

  // "schetId" field.
  DocumentReference? _schetId;
  DocumentReference? get schetId => _schetId;
  bool hasSchetId() => _schetId != null;

  // "schetTitle" field.
  String? _schetTitle;
  String get schetTitle => _schetTitle ?? '';
  bool hasSchetTitle() => _schetTitle != null;

  // "wallet_id" field.
  String? _walletId;
  String get walletId => _walletId ?? '';
  bool hasWalletId() => _walletId != null;

  // "wallet_name" field.
  String? _walletName;
  String get walletName => _walletName ?? '';
  bool hasWalletName() => _walletName != null;

  // "wallet_type" field.
  String? _walletType;
  String get walletType => _walletType ?? '';
  bool hasWalletType() => _walletType != null;

  // "money_flow_type" field.
  String? _moneyFlowType;
  String get moneyFlowType => _moneyFlowType ?? '';
  bool hasMoneyFlowType() => _moneyFlowType != null;
  MoneyFlowType get moneyFlowTypeEnum => inferMoneyFlowType(
        explicitValue: _moneyFlowType,
        transactionType: _type,
        category: _kat,
        description: _text,
        obligationId: _obligationId,
      );

  // "from_wallet_id" field.
  String? _fromWalletId;
  String get fromWalletId => _fromWalletId ?? '';
  bool hasFromWalletId() => _fromWalletId != null;

  // "to_wallet_id" field.
  String? _toWalletId;
  String get toWalletId => _toWalletId ?? '';
  bool hasToWalletId() => _toWalletId != null;

  // "date" field.
  DateTime? _date;
  DateTime? get date => _date;
  bool hasDate() => _date != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "counterparty" field.
  String? _counterparty;
  String get counterparty => _counterparty ?? '';
  bool hasCounterparty() => _counterparty != null;

  // "obligationId" field.
  String? _obligationId;
  String get obligationId => _obligationId ?? '';
  bool hasObligationId() => _obligationId != null;

  // "obligationTitle" field.
  String? _obligationTitle;
  String get obligationTitle => _obligationTitle ?? '';
  bool hasObligationTitle() => _obligationTitle != null;

  // "entry_ids" field.
  List<String>? _entryIds;
  List<String> get entryIds => _entryIds ?? const [];
  bool hasEntryIds() => _entryIds != null;

  void _initializeFields() {
    _type = _asString(snapshotData['type']);
    _typeUchet = _asString(snapshotData['typeUchet']);
    _ledgerScope = _asString(
      snapshotData['ledger_scope'] ?? snapshotData['ledgerScope'],
    );
    _kat = _asString(snapshotData['kat']);
    _text = _asString(snapshotData['text']);
    _comment = _asString(
      snapshotData['comment'] ??
          snapshotData['commentary'] ??
          snapshotData['memo'],
    );
    _paymentPeriod = _asString(
      snapshotData['payment_period'] ?? snapshotData['paymentPeriod'],
    );
    _summa = _asDouble(snapshotData['summa']) ??
        _asDouble(snapshotData['amount']) ??
        0.0;
    _amountCompany = _asDouble(
      snapshotData['amount_company'] ?? snapshotData['amountCompany'],
    );
    _amountOriginal = _asDouble(
      snapshotData['amount_original'] ?? snapshotData['amountOriginal'],
    );
    _currencyOriginal = _asString(
      snapshotData['currency_original'] ?? snapshotData['currencyOriginal'],
    );
    _companyCurrency = _asString(
      snapshotData['company_currency'] ?? snapshotData['companyCurrency'],
    );
    _exchangeRateToCompany = _asDouble(
      snapshotData['exchange_rate_to_company'] ??
          snapshotData['exchangeRateToCompany'],
    );
    _exchangeRateDate = _asDateTime(
      snapshotData['exchange_rate_date'] ?? snapshotData['exchangeRateDate'],
    );
    _exchangeRateSource = _asString(
      snapshotData['exchange_rate_source'] ??
          snapshotData['exchangeRateSource'],
    );
    _nds = _asBool(snapshotData['nds']);
    _summaNds = _asDouble(snapshotData['summaNds']) ?? 0.0;
    _taxRate = _asDouble(snapshotData['tax_rate'] ?? snapshotData['taxRate']);
    _taxProfileCountry = _asString(
      snapshotData['tax_profile_country'] ?? snapshotData['taxProfileCountry'],
    );
    _taxProfileVersion = _asString(
      snapshotData['tax_profile_version'] ?? snapshotData['taxProfileVersion'],
    );
    _taxable = _asBool(
      snapshotData['taxable'] ?? snapshotData['taxable_income'],
    );
    _deductible = _asBool(
      snapshotData['deductible'] ?? snapshotData['tax_deductible'],
    );
    _excludeFromCompanyIncome = _asBool(
      snapshotData['exclude_from_company_income'] ??
          snapshotData['excludeFromCompanyIncome'],
    );
    _idCompany = _asString(snapshotData['idCompany']);
    _schetId = _asDocumentReference(snapshotData['schetId']);
    _schetTitle = _asString(snapshotData['schetTitle']);
    _walletId =
        _asString(snapshotData['wallet_id'] ?? snapshotData['walletId']);
    _walletName =
        _asString(snapshotData['wallet_name'] ?? snapshotData['walletName']);
    _walletType =
        _asString(snapshotData['wallet_type'] ?? snapshotData['walletType']);
    _moneyFlowType = _asString(
      snapshotData['money_flow_type'] ?? snapshotData['moneyFlowType'],
    );
    _fromWalletId = _asString(
      snapshotData['from_wallet_id'] ?? snapshotData['fromWalletId'],
    );
    _toWalletId =
        _asString(snapshotData['to_wallet_id'] ?? snapshotData['toWalletId']);
    _date = _asDateTime(snapshotData['date']);
    _status = _asString(snapshotData['status']);
    _counterparty = _asString(snapshotData['counterparty']);
    _obligationId = _asString(snapshotData['obligationId']);
    _obligationTitle = _asString(snapshotData['obligationTitle']);
    _entryIds = getDataList(snapshotData['entry_ids']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('tranzaction');

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final raw = value.replaceAll('\u00A0', ' ').trim();
      if (raw.isEmpty) return null;

      final cleaned = raw.replaceAll(RegExp(r'[^0-9,.\-]'), '');
      if (cleaned.isEmpty || cleaned == '-') return null;

      final lastComma = cleaned.lastIndexOf(',');
      final lastDot = cleaned.lastIndexOf('.');
      String normalized;

      if (lastComma >= 0 && lastDot >= 0) {
        final decimalSep = lastComma > lastDot ? ',' : '.';
        final groupingSep = decimalSep == ',' ? '.' : ',';
        normalized = cleaned.replaceAll(groupingSep, '');
        if (decimalSep == ',') {
          normalized = normalized.replaceAll(',', '.');
        }
      } else {
        normalized = cleaned.replaceAll(',', '.');
      }

      return double.tryParse(normalized);
    }
    return null;
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static bool? _asBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final raw = value.toString().trim().toLowerCase();
    if (raw == 'true' || raw == '1' || raw == 'yes') return true;
    if (raw == 'false' || raw == '0' || raw == 'no') return false;
    return null;
  }

  static DocumentReference? _asDocumentReference(dynamic value) {
    return value is DocumentReference ? value : null;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static Stream<TranzactionRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => TranzactionRecord.fromSnapshot(s));

  static Future<TranzactionRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => TranzactionRecord.fromSnapshot(s));

  static TranzactionRecord fromSnapshot(DocumentSnapshot snapshot) =>
      TranzactionRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );

  static TranzactionRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      TranzactionRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'TranzactionRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is TranzactionRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createTranzactionRecordData({
  String? type,
  String? typeUchet,
  String? ledgerScope,
  String? kat,
  String? text,
  String? comment,
  String? paymentPeriod,
  double? summa,
  double? amountOriginal,
  String? currencyOriginal,
  double? exchangeRateToCompany,
  double? amountCompany,
  String? companyCurrency,
  DateTime? exchangeRateDate,
  String? exchangeRateSource,
  bool? nds,
  double? summaNds,
  double? taxRate,
  String? taxProfileCountry,
  String? taxProfileVersion,
  bool? taxable,
  bool? deductible,
  bool? excludeFromCompanyIncome,
  String? idCompany,
  DocumentReference? schetId,
  String? schetTitle,
  String? walletId,
  String? walletName,
  String? walletType,
  String? moneyFlowType,
  String? fromWalletId,
  String? fromWalletName,
  String? toWalletId,
  String? toWalletName,
  DateTime? date,
  String? status,
  String? counterparty,
  String? obligationId,
  String? obligationTitle,
  List<String>? entryIds,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'type': type,
      'typeUchet': typeUchet,
      'ledger_scope':
          ledgerScope ?? ledgerScopeFromLegacyValue(typeUchet).storageValue,
      'ledgerScope':
          ledgerScope ?? ledgerScopeFromLegacyValue(typeUchet).storageValue,
      'kat': kat,
      'text': text,
      'comment': comment,
      'commentary': comment,
      'payment_period': paymentPeriod,
      'paymentPeriod': paymentPeriod,
      'summa': summa,
      'amount': amountCompany ?? summa,
      'amount_company': amountCompany ?? summa,
      'amountCompany': amountCompany ?? summa,
      'amount_original': amountOriginal ?? summa,
      'amountOriginal': amountOriginal ?? summa,
      'currency_original': currencyOriginal,
      'currencyOriginal': currencyOriginal,
      'exchange_rate_to_company': exchangeRateToCompany,
      'exchangeRateToCompany': exchangeRateToCompany,
      'company_currency': companyCurrency,
      'companyCurrency': companyCurrency,
      'exchange_rate_date': exchangeRateDate,
      'exchangeRateDate': exchangeRateDate,
      'exchange_rate_source': exchangeRateSource,
      'exchangeRateSource': exchangeRateSource,
      'nds': nds,
      'summaNds': summaNds,
      'tax_rate': taxRate,
      'taxRate': taxRate,
      'tax_profile_country': taxProfileCountry,
      'taxProfileCountry': taxProfileCountry,
      'tax_profile_version': taxProfileVersion,
      'taxProfileVersion': taxProfileVersion,
      'taxable': taxable,
      'taxable_income': taxable,
      'deductible': deductible,
      'tax_deductible': deductible,
      'exclude_from_company_income': excludeFromCompanyIncome,
      'excludeFromCompanyIncome': excludeFromCompanyIncome,
      'idCompany': idCompany,
      'schetId': schetId,
      'schetTitle': schetTitle,
      'wallet_id': walletId,
      'walletId': walletId,
      'wallet_name': walletName,
      'walletName': walletName,
      'wallet_type': walletType,
      'walletType': walletType,
      'money_flow_type': inferMoneyFlowType(
        explicitValue: moneyFlowType,
        transactionType: type,
        category: kat,
        description: text,
        obligationId: obligationId,
      ).storageValue,
      'moneyFlowType': inferMoneyFlowType(
        explicitValue: moneyFlowType,
        transactionType: type,
        category: kat,
        description: text,
        obligationId: obligationId,
      ).storageValue,
      'from_wallet_id': fromWalletId,
      'fromWalletId': fromWalletId,
      'from_wallet_name': fromWalletName,
      'fromWalletName': fromWalletName,
      'to_wallet_id': toWalletId,
      'toWalletId': toWalletId,
      'to_wallet_name': toWalletName,
      'toWalletName': toWalletName,
      'date': date,
      'status': status,
      'counterparty': counterparty,
      'obligationId': obligationId,
      'obligationTitle': obligationTitle,
      'entry_ids': entryIds,
    }.withoutNulls,
  );

  return firestoreData;
}

class TranzactionRecordDocumentEquality implements Equality<TranzactionRecord> {
  const TranzactionRecordDocumentEquality();

  @override
  bool equals(TranzactionRecord? e1, TranzactionRecord? e2) {
    return e1?.type == e2?.type &&
        e1?.typeUchet == e2?.typeUchet &&
        e1?.ledgerScope == e2?.ledgerScope &&
        e1?.kat == e2?.kat &&
        e1?.text == e2?.text &&
        e1?.comment == e2?.comment &&
        e1?.paymentPeriod == e2?.paymentPeriod &&
        e1?.summa == e2?.summa &&
        e1?.amountCompany == e2?.amountCompany &&
        e1?.amountOriginal == e2?.amountOriginal &&
        e1?.currencyOriginal == e2?.currencyOriginal &&
        e1?.companyCurrency == e2?.companyCurrency &&
        e1?.exchangeRateToCompany == e2?.exchangeRateToCompany &&
        e1?.nds == e2?.nds &&
        e1?.summaNds == e2?.summaNds &&
        e1?.taxable == e2?.taxable &&
        e1?.deductible == e2?.deductible &&
        e1?.excludeFromCompanyIncome == e2?.excludeFromCompanyIncome &&
        e1?.idCompany == e2?.idCompany &&
        e1?.schetId == e2?.schetId &&
        e1?.schetTitle == e2?.schetTitle &&
        e1?.walletId == e2?.walletId &&
        e1?.walletName == e2?.walletName &&
        e1?.walletType == e2?.walletType &&
        e1?.moneyFlowType == e2?.moneyFlowType &&
        e1?.fromWalletId == e2?.fromWalletId &&
        e1?.toWalletId == e2?.toWalletId &&
        e1?.date == e2?.date &&
        e1?.status == e2?.status &&
        e1?.counterparty == e2?.counterparty &&
        e1?.obligationId == e2?.obligationId &&
        e1?.obligationTitle == e2?.obligationTitle &&
        const ListEquality().equals(e1?.entryIds, e2?.entryIds);
  }

  @override
  int hash(TranzactionRecord? e) => const ListEquality().hash([
        e?.type,
        e?.typeUchet,
        e?.ledgerScope,
        e?.kat,
        e?.text,
        e?.comment,
        e?.paymentPeriod,
        e?.summa,
        e?.amountCompany,
        e?.amountOriginal,
        e?.currencyOriginal,
        e?.companyCurrency,
        e?.exchangeRateToCompany,
        e?.nds,
        e?.summaNds,
        e?.taxable,
        e?.deductible,
        e?.excludeFromCompanyIncome,
        e?.idCompany,
        e?.schetId,
        e?.schetTitle,
        e?.walletId,
        e?.walletName,
        e?.walletType,
        e?.moneyFlowType,
        e?.fromWalletId,
        e?.toWalletId,
        e?.date,
        e?.status,
        e?.counterparty,
        e?.obligationId,
        e?.obligationTitle,
        e?.entryIds,
      ]);

  @override
  bool isValidKey(Object? o) => o is TranzactionRecord;
}
