import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/accounting_entry_record.dart';
import '/backend/schema/util/firestore_util.dart';
import '/utils/country_tax_profile.dart';
import '/utils/income_exclusion_support.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_amount.dart';
import '/utils/money_flow_type.dart';

const double defaultTransactionNdsRate = kzDefaultNdsRate;

class AccountingEntryException implements Exception {
  const AccountingEntryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AccountingEntryDraft {
  const AccountingEntryDraft({
    required this.debitAccountId,
    required this.creditAccountId,
    required this.amount,
    required this.ledgerScope,
    required this.idCompany,
    required this.moneyFlowType,
    this.debitSchetRef,
    this.debitAccountTitle,
    this.creditSchetRef,
    this.creditAccountTitle,
    this.description,
    this.memo,
    this.taxKind,
    this.taxable = false,
    this.deductible = false,
    this.taxRate = 0,
    this.taxAmount = 0,
    this.currency = 'KZT',
    this.entryDate,
    this.sourceType = 'transaction',
  });

  final String debitAccountId;
  final DocumentReference? debitSchetRef;
  final String? debitAccountTitle;
  final String creditAccountId;
  final DocumentReference? creditSchetRef;
  final String? creditAccountTitle;
  final double amount;
  final LedgerScope ledgerScope;
  final String idCompany;
  final MoneyFlowType moneyFlowType;
  final String? description;
  final String? memo;
  final String? taxKind;
  final bool taxable;
  final bool deductible;
  final double taxRate;
  final double taxAmount;
  final String currency;
  final dynamic entryDate;
  final String sourceType;
}

class AccountingEntryWriteResult {
  const AccountingEntryWriteResult({
    required this.entryIds,
    required this.payloads,
  });

  final List<String> entryIds;
  final List<Map<String, dynamic>> payloads;
}

class AccountingEntryResolutionResult {
  const AccountingEntryResolutionResult({
    required this.payloads,
    required this.usedLegacyFallback,
  });

  final List<Map<String, dynamic>> payloads;
  final bool usedLegacyFallback;
}

class AccountingEntryPayloadBuildResult {
  const AccountingEntryPayloadBuildResult({
    required this.entryIds,
    required this.writes,
  });

  final List<String> entryIds;
  final List<MapEntry<DocumentReference, Map<String, dynamic>>> writes;
}

String virtualIncomeAccountId({
  required LedgerScope ledgerScope,
  required String category,
}) {
  final normalizedCategory =
      category.trim().isEmpty ? 'general' : category.trim();
  return 'virtual:income:${ledgerScope.storageValue}:$normalizedCategory';
}

String virtualExpenseAccountId({
  required LedgerScope ledgerScope,
  required String category,
}) {
  final normalizedCategory =
      category.trim().isEmpty ? 'general' : category.trim();
  return 'virtual:expense:${ledgerScope.storageValue}:$normalizedCategory';
}

String virtualEquityAccountId({
  required LedgerScope ledgerScope,
  required String category,
}) {
  final normalizedCategory =
      category.trim().isEmpty ? 'general' : category.trim();
  return 'virtual:equity:${ledgerScope.storageValue}:$normalizedCategory';
}

String virtualAssetAccountId({
  required LedgerScope ledgerScope,
  required String category,
}) {
  final normalizedCategory =
      category.trim().isEmpty ? 'general' : category.trim();
  return 'virtual:asset:${ledgerScope.storageValue}:$normalizedCategory';
}

String virtualTaxRefundAccountId({
  required LedgerScope ledgerScope,
}) {
  return 'virtual:tax_refund:${ledgerScope.storageValue}';
}

String virtualReceivableAccountId({
  required LedgerScope ledgerScope,
  required String counterparty,
}) {
  final normalizedCounterparty =
      counterparty.trim().isEmpty ? 'receivable' : counterparty.trim();
  return 'virtual:asset:receivable:${ledgerScope.storageValue}:$normalizedCounterparty';
}

String virtualPayableAccountId({
  required LedgerScope ledgerScope,
  required String counterparty,
}) {
  final normalizedCounterparty =
      counterparty.trim().isEmpty ? 'payable' : counterparty.trim();
  return 'virtual:liability:payable:${ledgerScope.storageValue}:$normalizedCounterparty';
}

List<AccountingEntryDraft> buildEntriesForTransactionData({
  required String transactionId,
  required Map<String, dynamic> transactionData,
}) {
  if (!transactionIsPosted(transactionData)) {
    return const [];
  }
  final type = (transactionData['type'] ?? '').toString().trim().toLowerCase();
  final companyId = (transactionData['idCompany'] ?? '').toString().trim();
  final amount = companyAmountFromData(transactionData);
  if (companyId.isEmpty) {
    throw const AccountingEntryException('Company id is required');
  }
  if (amount <= 0) {
    throw const AccountingEntryException('Transaction amount must be positive');
  }

  final ledgerScope = ledgerScopeFromData(transactionData);
  final category = (transactionData['kat'] ?? '').toString();
  final description = (transactionData['text'] ?? '').toString();
  final comment = (transactionData['comment'] ??
          transactionData['commentary'] ??
          transactionData['memo'] ??
          '')
      .toString();
  final paymentPeriod = (transactionData['payment_period'] ??
          transactionData['paymentPeriod'] ??
          '')
      .toString();
  final counterparty = (transactionData['counterparty'] ?? '').toString();
  final memoParts = [
    counterparty,
    if (paymentPeriod.trim().isNotEmpty) 'Период: $paymentPeriod',
    comment,
  ].where((part) => part.trim().isNotEmpty).join(' · ');
  final moneyFlowType = inferMoneyFlowType(
    explicitValue:
        (transactionData['money_flow_type'] ?? transactionData['moneyFlowType'])
            ?.toString(),
    transactionType: type,
    category: category,
    description: description,
    obligationId: (transactionData['obligationId'] ?? '').toString(),
  );
  final entryDate = transactionData['date'] ?? FieldValue.serverTimestamp();
  final ndsEnabled = transactionData['nds'] == true;
  final taxable = _bool(
    transactionData['taxable'] ?? transactionData['taxable_income'],
    fallback: ndsEnabled,
  );
  final deductible = _bool(
    transactionData['deductible'] ?? transactionData['tax_deductible'],
    fallback: ndsEnabled,
  );
  final taxProfile = taxProfileFromData(
    transactionData,
    date: _dateFromValue(transactionData['date']),
  );
  final ndsRate = _num(transactionData['tax_rate'] ??
      transactionData['taxRate'] ??
      transactionData['ndsRate'] ??
      taxProfile.vatRate);
  final ndsAmountRaw = _num(transactionData['summaNds']);
  final effectiveTaxRate = ndsRate > 1 ? ndsRate / 100 : ndsRate;
  final incomeTaxAmount = ndsEnabled
      ? (ndsAmountRaw > 0 ? ndsAmountRaw : amount * effectiveTaxRate)
      : 0.0;
  final deductibleTaxAmount = deductible
      ? (ndsAmountRaw > 0 ? ndsAmountRaw : amount * effectiveTaxRate)
      : 0.0;
  final accountRef = transactionData['schetId'] is DocumentReference
      ? transactionData['schetId'] as DocumentReference
      : null;
  final accountId = accountRef?.id ??
      (transactionData['schet_id'] ?? transactionData['schetId'] ?? '')
          .toString()
          .trim();
  final accountTitle = (transactionData['schetTitle'] ?? '').toString();
  final companyCurrency = companyCurrencyFromData(
    transactionData,
    fallback: taxProfile.countryCode == 'TJ' ? 'TJS' : 'KZT',
  );
  final receivableDebtId = (transactionData['receivable_debt_id'] ??
          transactionData['receivableDebtId'] ??
          '')
      .toString()
      .trim();
  final receivableCounterparty =
      (transactionData['counterparty'] ?? 'Дебиторка').toString();
  final settlesReceivable = transactionData['settles_receivable'] == true ||
      transactionData['settlesReceivable'] == true;
  final excludeFromCompanyIncome =
      transactionData['exclude_from_company_income'] == true ||
          transactionData['excludeFromCompanyIncome'] == true;
  final isTaxRefund =
      looksLikeTaxRefund(category) || looksLikeTaxRefund(description);
  final obligationId = (transactionData['obligationId'] ??
          transactionData['obligation_id'] ??
          '')
      .toString()
      .trim();

  if (type == 'transfer') {
    final sourceRef = transactionData['sourceSchetId'] is DocumentReference
        ? transactionData['sourceSchetId'] as DocumentReference
        : null;
    final targetRef = transactionData['targetSchetId'] is DocumentReference
        ? transactionData['targetSchetId'] as DocumentReference
        : null;
    final sourceId = sourceRef?.id ??
        (transactionData['source_schet_id'] ?? '').toString().trim();
    final targetId = targetRef?.id ??
        (transactionData['target_schet_id'] ?? '').toString().trim();
    if (sourceId.isEmpty || targetId.isEmpty) {
      throw const AccountingEntryException(
        'Transfer transaction requires source and target accounts',
      );
    }
    return [
      AccountingEntryDraft(
        debitAccountId: targetId,
        debitSchetRef: targetRef,
        debitAccountTitle:
            (transactionData['targetSchetTitle'] ?? '').toString(),
        creditAccountId: sourceId,
        creditSchetRef: sourceRef,
        creditAccountTitle:
            (transactionData['sourceSchetTitle'] ?? '').toString(),
        amount: amount,
        ledgerScope: ledgerScope,
        idCompany: companyId,
        moneyFlowType: MoneyFlowType.transfer,
        description: description,
        memo: memoParts,
        currency: companyCurrency,
        entryDate: entryDate,
      ),
    ];
  }

  if (accountId.isEmpty && receivableDebtId.isEmpty) {
    throw const AccountingEntryException(
      'Transaction account is required for posting generation',
    );
  }

  if (type == 'income' || type == 'доход' || type == 'doxod') {
    final debitAccountId = receivableDebtId.isNotEmpty
        ? virtualReceivableAccountId(
            ledgerScope: ledgerScope,
            counterparty: receivableCounterparty,
          )
        : accountId;
    final creditAccountId = settlesReceivable
        ? virtualReceivableAccountId(
            ledgerScope: ledgerScope,
            counterparty: receivableCounterparty,
          )
        : excludeFromCompanyIncome || isTaxRefund
            ? virtualTaxRefundAccountId(ledgerScope: ledgerScope)
            : moneyFlowType == MoneyFlowType.financing
                ? virtualEquityAccountId(
                    ledgerScope: ledgerScope,
                    category: category,
                  )
                : moneyFlowType == MoneyFlowType.investing
                    ? virtualAssetAccountId(
                        ledgerScope: ledgerScope,
                        category: category,
                      )
                    : virtualIncomeAccountId(
                        ledgerScope: ledgerScope,
                        category: category,
                      );
    return [
      AccountingEntryDraft(
        debitAccountId: debitAccountId,
        debitSchetRef: receivableDebtId.isNotEmpty ? null : accountRef,
        debitAccountTitle:
            receivableDebtId.isNotEmpty ? 'Дебиторка' : accountTitle,
        creditAccountId: creditAccountId,
        creditAccountTitle: settlesReceivable ? 'Дебиторка' : category,
        amount: amount,
        ledgerScope: ledgerScope,
        idCompany: companyId,
        moneyFlowType: moneyFlowType,
        description: description,
        memo: memoParts,
        taxKind: ndsEnabled ? 'vat_output' : null,
        taxable: taxable,
        deductible: false,
        taxRate: effectiveTaxRate,
        taxAmount: incomeTaxAmount,
        currency: companyCurrency,
        entryDate: entryDate,
      ),
    ];
  }

  if (type == 'decome' ||
      type == 'expense' ||
      type == 'расход' ||
      type == 'rashod') {
    final obligationTitle =
        (transactionData['obligationTitle'] ?? '').toString().trim();
    final expenseCategory = obligationTitle.isNotEmpty
        ? obligationTitle
        : category.trim().isEmpty
            ? description
            : category;
    final settlesPayable = obligationId.isNotEmpty;
    final debitAccountId = settlesPayable
        ? virtualPayableAccountId(
            ledgerScope: ledgerScope,
            counterparty: receivableCounterparty,
          )
        : moneyFlowType == MoneyFlowType.financing
            ? virtualEquityAccountId(
                ledgerScope: ledgerScope,
                category: category,
              )
            : moneyFlowType == MoneyFlowType.investing
                ? virtualAssetAccountId(
                    ledgerScope: ledgerScope,
                    category: category,
                  )
                : virtualExpenseAccountId(
                    ledgerScope: ledgerScope,
                    category: expenseCategory,
                  );
    return [
      AccountingEntryDraft(
        debitAccountId: debitAccountId,
        debitAccountTitle: settlesPayable ? 'Кредиторка' : expenseCategory,
        creditAccountId: accountId,
        creditSchetRef: accountRef,
        creditAccountTitle: accountTitle,
        amount: amount,
        ledgerScope: ledgerScope,
        idCompany: companyId,
        moneyFlowType: moneyFlowType,
        description: description,
        memo: memoParts,
        taxKind: deductible ? 'vat_input' : null,
        taxable: false,
        deductible: deductible,
        taxRate: effectiveTaxRate,
        taxAmount: deductibleTaxAmount,
        currency: companyCurrency,
        entryDate: entryDate,
      ),
    ];
  }

  throw AccountingEntryException('Unsupported transaction type: $type');
}

AccountingEntryDraft buildEntryForObligationData({
  required String obligationId,
  required Map<String, dynamic> obligationData,
}) {
  final companyId = (obligationData['idCompany'] ??
          obligationData['companyId'] ??
          obligationData['company_id'] ??
          '')
      .toString()
      .trim();
  final amount = companyAmountFromData(obligationData);
  if (companyId.isEmpty) {
    throw const AccountingEntryException('Company id is required');
  }
  if (amount <= 0) {
    throw const AccountingEntryException('Obligation amount must be positive');
  }

  final ledgerScope = ledgerScopeFromData(obligationData);
  final title = (obligationData['title'] ??
          obligationData['name'] ??
          obligationData['type'] ??
          'Обязательство')
      .toString()
      .trim();
  final category = (obligationData['category_name'] ??
          obligationData['budget_category'] ??
          obligationData['kat'] ??
          title)
      .toString()
      .trim();
  final counterparty = (obligationData['counterparty'] ?? '').toString();
  final description = title.isEmpty ? category : title;
  final memo = [
    counterparty,
    (obligationData['description'] ?? '').toString(),
  ].where((part) => part.trim().isNotEmpty).join(' · ');
  final taxProfile = taxProfileFromData(obligationData);
  final companyCurrency = companyCurrencyFromData(
    obligationData,
    fallback: taxProfile.countryCode == 'TJ' ? 'TJS' : 'KZT',
  );

  return AccountingEntryDraft(
    debitAccountId: virtualExpenseAccountId(
      ledgerScope: ledgerScope,
      category: category.isEmpty ? description : category,
    ),
    debitAccountTitle: category.isEmpty ? description : category,
    creditAccountId: virtualPayableAccountId(
      ledgerScope: ledgerScope,
      counterparty: counterparty,
    ),
    creditAccountTitle: 'Кредиторка',
    amount: amount,
    ledgerScope: ledgerScope,
    idCompany: companyId,
    moneyFlowType: inferMoneyFlowType(
      explicitValue:
          (obligationData['money_flow_type'] ?? obligationData['moneyFlowType'])
              ?.toString(),
      transactionType: 'decome',
      category: category,
      description: description,
      obligationId: obligationId,
    ),
    description: description,
    memo: memo,
    currency: companyCurrency,
    entryDate: obligationData['created_at'] ??
        obligationData['date'] ??
        FieldValue.serverTimestamp(),
    sourceType: 'obligation',
  );
}

Future<AccountingEntryWriteResult> upsertEntryForObligation({
  required FirebaseFirestore firestore,
  required DocumentReference obligationRef,
  required Map<String, dynamic> obligationData,
}) async {
  final obligationId = obligationRef.id;
  final existing = await firestore
      .collection('accounting_entries')
      .where('source_type', isEqualTo: 'obligation')
      .where('source_id', isEqualTo: obligationId)
      .get();
  final draft = buildEntryForObligationData(
    obligationId: obligationId,
    obligationData: obligationData,
  );
  final ref = existing.docs.isEmpty
      ? firestore.collection('accounting_entries').doc()
      : existing.docs.first.reference;
  final payload = createAccountingEntryRecordData(
    transactionId: obligationId,
    sourceType: draft.sourceType,
    sourceId: obligationId,
    entryDate: draft.entryDate,
    debitAccountId: draft.debitAccountId,
    debitAccountTitle: draft.debitAccountTitle,
    creditAccountId: draft.creditAccountId,
    creditAccountTitle: draft.creditAccountTitle,
    amount: draft.amount,
    currency: draft.currency,
    ledgerScope: draft.ledgerScope.storageValue,
    moneyFlowType: draft.moneyFlowType.storageValue,
    description: draft.description,
    memo: draft.memo,
    taxable: draft.taxable,
    deductible: draft.deductible,
    taxRate: draft.taxRate,
    taxAmount: draft.taxAmount,
    idCompany: draft.idCompany,
    createdAt: existing.docs.isEmpty ? FieldValue.serverTimestamp() : null,
    updatedAt: FieldValue.serverTimestamp(),
  );
  final batch = firestore.batch();
  for (final extra in existing.docs.skip(1)) {
    batch.delete(extra.reference);
  }
  batch.set(ref, payload, SetOptions(merge: true));
  batch.update(obligationRef, {
    'entry_id': ref.id,
    'entry_ids': [ref.id],
    'entry_generated_at': FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return AccountingEntryWriteResult(
    entryIds: [ref.id],
    payloads: [payload],
  );
}

Future<List<AccountingEntryRecord>> getEntriesByTransaction(
  FirebaseFirestore firestore,
  String transactionId,
) async {
  if (transactionId.trim().isEmpty) return const [];
  final snap = await firestore
      .collection('accounting_entries')
      .where('transaction_id', isEqualTo: transactionId.trim())
      .get();
  return snap.docs
      .map((doc) => AccountingEntryRecord.fromSnapshot(doc))
      .toList();
}

bool transactionHasStoredEntryIds(Map<String, dynamic> transactionData) {
  final rawEntryIds = transactionData['entry_ids'];
  return rawEntryIds is Iterable && rawEntryIds.isNotEmpty;
}

List<Map<String, dynamic>> buildFallbackEntryPayloadsForTransaction({
  required String transactionId,
  required Map<String, dynamic> transactionData,
}) {
  final drafts = buildEntriesForTransactionData(
    transactionId: transactionId,
    transactionData: transactionData,
  );
  return drafts
      .map(
        (draft) => createAccountingEntryRecordData(
          transactionId: transactionId,
          sourceType: draft.sourceType,
          sourceId: transactionId,
          entryDate: draft.entryDate,
          debitAccountId: draft.debitAccountId,
          debitSchetRef: draft.debitSchetRef,
          debitAccountTitle: draft.debitAccountTitle,
          creditAccountId: draft.creditAccountId,
          creditSchetRef: draft.creditSchetRef,
          creditAccountTitle: draft.creditAccountTitle,
          amount: draft.amount,
          currency: draft.currency,
          ledgerScope: draft.ledgerScope.storageValue,
          moneyFlowType: draft.moneyFlowType.storageValue,
          description: draft.description,
          memo: draft.memo,
          taxKind: draft.taxKind,
          taxable: draft.taxable,
          deductible: draft.deductible,
          taxRate: draft.taxRate,
          taxAmount: draft.taxAmount,
          idCompany: draft.idCompany,
        ),
      )
      .toList();
}

Future<AccountingEntryResolutionResult> getEntryPayloadsForTransaction({
  required FirebaseFirestore firestore,
  required String transactionId,
  required Map<String, dynamic> transactionData,
  bool allowLegacyFallback = true,
}) async {
  final existing = await getEntriesByTransaction(firestore, transactionId);
  if (existing.isNotEmpty) {
    return AccountingEntryResolutionResult(
      payloads: existing.map((entry) => entry.snapshotData).toList(),
      usedLegacyFallback: false,
    );
  }
  if (!allowLegacyFallback || transactionHasStoredEntryIds(transactionData)) {
    return const AccountingEntryResolutionResult(
      payloads: [],
      usedLegacyFallback: false,
    );
  }
  return AccountingEntryResolutionResult(
    payloads: buildFallbackEntryPayloadsForTransaction(
      transactionId: transactionId,
      transactionData: transactionData,
    ),
    usedLegacyFallback: true,
  );
}

Future<AccountingEntryWriteResult> createEntriesForTransaction({
  required FirebaseFirestore firestore,
  required DocumentReference transactionRef,
  required Map<String, dynamic> transactionData,
  bool overwriteExisting = false,
}) async {
  final txId = transactionRef.id;
  final existing = await getEntriesByTransaction(firestore, txId);
  if (existing.isNotEmpty && !overwriteExisting) {
    return AccountingEntryWriteResult(
      entryIds: existing.map((e) => e.reference.id).toList(),
      payloads: existing.map((e) => e.snapshotData).toList(),
    );
  }

  final drafts = buildEntriesForTransactionData(
    transactionId: txId,
    transactionData: transactionData,
  );
  final batch = firestore.batch();
  final payloads = <Map<String, dynamic>>[];
  final entryIds = <String>[];

  if (existing.isNotEmpty && overwriteExisting) {
    for (final entry in existing) {
      batch.delete(entry.reference);
    }
  }

  for (final draft in drafts) {
    final ref = firestore.collection('accounting_entries').doc();
    final payload = createAccountingEntryRecordData(
      transactionId: txId,
      sourceType: draft.sourceType,
      sourceId: txId,
      entryDate: draft.entryDate,
      debitAccountId: draft.debitAccountId,
      debitSchetRef: draft.debitSchetRef,
      debitAccountTitle: draft.debitAccountTitle,
      creditAccountId: draft.creditAccountId,
      creditSchetRef: draft.creditSchetRef,
      creditAccountTitle: draft.creditAccountTitle,
      amount: draft.amount,
      currency: draft.currency,
      ledgerScope: draft.ledgerScope.storageValue,
      moneyFlowType: draft.moneyFlowType.storageValue,
      description: draft.description,
      memo: draft.memo,
      taxKind: draft.taxKind,
      taxable: draft.taxable,
      deductible: draft.deductible,
      taxRate: draft.taxRate,
      taxAmount: draft.taxAmount,
      idCompany: draft.idCompany,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    );
    batch.set(ref, payload);
    payloads.add(payload);
    entryIds.add(ref.id);
  }

  batch.update(
    transactionRef,
    mapToFirestore({
      'entry_ids': entryIds,
      'entries_generated_at': FieldValue.serverTimestamp(),
    }),
  );
  await batch.commit();

  return AccountingEntryWriteResult(entryIds: entryIds, payloads: payloads);
}

AccountingEntryPayloadBuildResult buildEntryPayloadsForTransaction({
  required FirebaseFirestore firestore,
  required DocumentReference transactionRef,
  required Map<String, dynamic> transactionData,
}) {
  final drafts = buildEntriesForTransactionData(
    transactionId: transactionRef.id,
    transactionData: transactionData,
  );
  final writes = <MapEntry<DocumentReference, Map<String, dynamic>>>[];
  final entryIds = <String>[];
  for (final draft in drafts) {
    final ref = firestore.collection('accounting_entries').doc();
    final payload = createAccountingEntryRecordData(
      transactionId: transactionRef.id,
      sourceType: draft.sourceType,
      sourceId: transactionRef.id,
      entryDate: draft.entryDate,
      debitAccountId: draft.debitAccountId,
      debitSchetRef: draft.debitSchetRef,
      debitAccountTitle: draft.debitAccountTitle,
      creditAccountId: draft.creditAccountId,
      creditSchetRef: draft.creditSchetRef,
      creditAccountTitle: draft.creditAccountTitle,
      amount: draft.amount,
      currency: draft.currency,
      ledgerScope: draft.ledgerScope.storageValue,
      moneyFlowType: draft.moneyFlowType.storageValue,
      description: draft.description,
      memo: draft.memo,
      taxKind: draft.taxKind,
      taxable: draft.taxable,
      deductible: draft.deductible,
      taxRate: draft.taxRate,
      taxAmount: draft.taxAmount,
      idCompany: draft.idCompany,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    );
    writes.add(MapEntry(ref, payload));
    entryIds.add(ref.id);
  }
  return AccountingEntryPayloadBuildResult(
    entryIds: entryIds,
    writes: writes,
  );
}

Future<void> deleteEntriesByTransaction({
  required FirebaseFirestore firestore,
  required String transactionId,
}) async {
  final trimmedId = transactionId.trim();
  if (trimmedId.isEmpty) return;
  final existing = await getEntriesByTransaction(firestore, trimmedId);
  if (existing.isEmpty) return;
  final batch = firestore.batch();
  for (final entry in existing) {
    batch.delete(entry.reference);
  }
  await batch.commit();
}

Future<AccountingEntryWriteResult> rebuildEntriesForLegacyTransaction({
  required FirebaseFirestore firestore,
  required DocumentReference transactionRef,
  required Map<String, dynamic> transactionData,
}) {
  return createEntriesForTransaction(
    firestore: firestore,
    transactionRef: transactionRef,
    transactionData: transactionData,
    overwriteExisting: true,
  );
}

double _num(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

DateTime? _dateFromValue(dynamic value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}

bool transactionIsPosted(Map<String, dynamic> transactionData) {
  final status =
      (transactionData['status'] ?? '').toString().trim().toLowerCase();
  if (status.isEmpty) return true;
  return status == 'проведена' ||
      status == 'проведен' ||
      status == 'проведено' ||
      status == 'проведён' ||
      status == 'posted' ||
      status == 'completed' ||
      status == 'paid';
}

bool _bool(dynamic value, {required bool fallback}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return fallback;
}
