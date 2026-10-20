import '/backend/backend.dart';
import '/custom_code/widgets/personal_finance_support.dart';
import '/utils/accounting_entry_service.dart';
import '/utils/money_flow_type.dart';
import '/utils/transaction_sync.dart';

const String legacyPersonalInvestmentSource = 'personal_investment';
const String companyExpenseSource = 'personal_company_expense';
const String ownerInvestmentDisplayLabel = 'Ввод остатков';

final Set<String> _normalizedOwnerInvestmentCompanies = <String>{};

bool looksLikeOwnerInvestmentLabel(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  return normalized.contains('вложен') ||
      normalized.contains('ввод остат') ||
      normalized.contains('фин.пом') ||
      normalized.contains('фин пом') ||
      normalized.contains('финансовая помощь') ||
      normalized.contains('учредител');
}

bool isOwnerInvestmentPayload(Map<String, dynamic> item) {
  final source = (item['source'] ?? '').toString().trim();
  if (source == legacyPersonalInvestmentSource) {
    return true;
  }
  final values = <String>[
    (item['source_label'] ?? '').toString(),
    (item['category'] ?? '').toString(),
    (item['category_title'] ?? '').toString(),
    (item['subcategory1_title'] ?? '').toString(),
    (item['subcategory2_title'] ?? '').toString(),
    (item['description'] ?? '').toString(),
    (item['kat'] ?? '').toString(),
    (item['text'] ?? '').toString(),
    (item['counterparty'] ?? '').toString(),
  ];
  if ((item['money_flow_type'] ?? item['moneyFlowType'] ?? '')
          .toString()
          .trim()
          .toLowerCase() ==
      MoneyFlowType.financing.storageValue) {
    if (values.any(looksLikeOwnerInvestmentLabel) ||
        (item['counterparty'] ?? '').toString().trim() ==
            'Личные средства владельца') {
      return true;
    }
  }
  return values.any(looksLikeOwnerInvestmentLabel);
}

bool isOwnerInvestmentTransaction(TranzactionRecord item) {
  return isOwnerInvestmentPayload(<String, dynamic>{
    'source': '',
    'money_flow_type': item.moneyFlowType,
    'moneyFlowType': item.moneyFlowType,
    'category': item.kat,
    'category_title': item.kat,
    'description': item.text,
    'kat': item.kat,
    'text': item.text,
    'counterparty': item.counterparty,
  });
}

Future<void> _deleteBusinessEventsByTransaction(
  FirebaseFirestore firestore,
  String transactionId,
) async {
  if (transactionId.trim().isEmpty) return;
  final snap = await firestore
      .collection('business_events')
      .where('transaction_id', isEqualTo: transactionId.trim())
      .get();
  if (snap.docs.isEmpty) return;
  final batch = firestore.batch();
  for (final doc in snap.docs) {
    batch.delete(doc.reference);
  }
  await batch.commit();
}

Future<bool> ensureOwnerInvestmentsNormalizedForCompany({
  required FirebaseFirestore firestore,
  required String companyId,
}) async {
  if (companyId.trim().isEmpty) return false;
  if (_normalizedOwnerInvestmentCompanies.contains(companyId)) {
    return false;
  }

  var changed = false;
  final expensesSnap = await firestore
      .collection('company_expenses')
      .where('idCompany', isEqualTo: companyId)
      .limit(300)
      .get(const GetOptions(source: Source.serverAndCache));
  final expenses = expensesSnap.docs
      .map((d) => <String, dynamic>{'id': d.id, ...Map<String, dynamic>.from(d.data())})
      .toList(growable: false);

  for (final item in expenses) {
    if (!isOwnerInvestmentPayload(item)) continue;

    final expenseId = (item['id'] ?? '').toString();
    final transactionId = (item['tranzaction_id'] ?? '').toString();
    final personalEntryId = (item['personal_entry_id'] ?? '').toString();
    final categoryTitle =
        (item['category_title'] ?? item['category'] ?? 'Вложение в компанию')
            .toString()
            .trim();
    final description = (item['description'] ?? '').toString().trim().isEmpty
        ? 'Ввод остатков владельца'
        : (item['description'] ?? '').toString().trim();

    if (expenseId.isNotEmpty) {
      final companyExpensePatch = <String, dynamic>{};
      final source = (item['source'] ?? '').toString();
      final flow = (item['money_flow_type'] ?? item['moneyFlowType'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (source != legacyPersonalInvestmentSource) {
        companyExpensePatch['source'] = legacyPersonalInvestmentSource;
      }
      if (flow != MoneyFlowType.financing.storageValue) {
        companyExpensePatch['money_flow_type'] =
            MoneyFlowType.financing.storageValue;
        companyExpensePatch['moneyFlowType'] =
            MoneyFlowType.financing.storageValue;
      }
      if (companyExpensePatch.isNotEmpty) {
        await firestore.collection('company_expenses').doc(expenseId).update(
              companyExpensePatch,
            );
        changed = true;
      }
    }

    if (personalEntryId.isNotEmpty) {
      final personalRef =
          firestore.collection(PersonalFinanceSupport.entriesCollection).doc(
                personalEntryId,
              );
      final personalSnap =
          await personalRef.get(const GetOptions(source: Source.serverAndCache));
      if (personalSnap.exists && personalSnap.data() != null) {
        final data = Map<String, dynamic>.from(personalSnap.data()!);
        final personalPatch = <String, dynamic>{};
        final source = (data['source'] ?? '').toString();
        final sourceLabel = (data['source_label'] ?? '').toString();
        final flow = (data['money_flow_type'] ?? data['moneyFlowType'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (source != legacyPersonalInvestmentSource) {
          personalPatch['source'] = legacyPersonalInvestmentSource;
        }
        if (sourceLabel != ownerInvestmentDisplayLabel) {
          personalPatch['source_label'] = ownerInvestmentDisplayLabel;
        }
        if (flow != MoneyFlowType.financing.storageValue) {
          personalPatch['money_flow_type'] =
              MoneyFlowType.financing.storageValue;
          personalPatch['moneyFlowType'] =
              MoneyFlowType.financing.storageValue;
        }
        if ((data['description'] ?? '').toString().trim().isEmpty ||
            (data['description'] ?? '')
                .toString()
                .trim()
                .toLowerCase()
                .contains('расход на компанию')) {
          personalPatch['description'] = ownerInvestmentDisplayLabel;
        }
        if (personalPatch.isNotEmpty) {
          await personalRef.update(personalPatch);
          changed = true;
        }
      }
    }

    if (transactionId.isNotEmpty) {
      final txRef = firestore.collection('tranzaction').doc(transactionId);
      final txSnap =
          await txRef.get(const GetOptions(source: Source.serverAndCache));
      if (txSnap.exists && txSnap.data() != null) {
        final txData = Map<String, dynamic>.from(txSnap.data()!);
        final txPatch = <String, dynamic>{};
        final type = (txData['type'] ?? '').toString().trim().toLowerCase();
        final flow = (txData['money_flow_type'] ?? txData['moneyFlowType'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (type != 'income') {
          txPatch['type'] = 'income';
        }
        if (flow != MoneyFlowType.financing.storageValue) {
          txPatch['money_flow_type'] = MoneyFlowType.financing.storageValue;
          txPatch['moneyFlowType'] = MoneyFlowType.financing.storageValue;
        }
        if ((txData['kat'] ?? '').toString().trim() != categoryTitle) {
          txPatch['kat'] = categoryTitle;
        }
        if ((txData['counterparty'] ?? '').toString().trim() !=
            'Личные средства владельца') {
          txPatch['counterparty'] = 'Личные средства владельца';
        }
        if ((txData['text'] ?? '').toString().trim().isEmpty ||
            (txData['text'] ?? '')
                .toString()
                .trim()
                .toLowerCase()
                .contains('расход на компанию')) {
          txPatch['text'] = description;
        }
        if (txPatch.isNotEmpty) {
          await txRef.update(txPatch);
          txData.addAll(txPatch);
          await createEntriesForTransaction(
            firestore: firestore,
            transactionRef: txRef,
            transactionData: txData,
            overwriteExisting: true,
          );
          changed = true;
        }
      }

      final eventSnap = await firestore
          .collection('business_events')
          .where('transaction_id', isEqualTo: transactionId)
          .limit(1)
          .get(const GetOptions(source: Source.serverAndCache));
      if (eventSnap.docs.isNotEmpty) {
        await _deleteBusinessEventsByTransaction(firestore, transactionId);
        changed = true;
      }
    }
  }

  _normalizedOwnerInvestmentCompanies.add(companyId);
  if (!changed) return false;

  await TransactionSync.recomputeAllForCompany(companyId);
  FirestoreQueryCache.instance.invalidateCompanyCollection(
    'company_expenses',
    companyId,
  );
  FirestoreQueryCache.instance.invalidateCompanyCollection(
    'accounting_entries',
    companyId,
  );
  FirestoreQueryCache.instance.invalidateCompanyCollection(
    'tranzaction',
    companyId,
  );
  FirestoreQueryCache.instance.invalidateCompanyCollection('sheta', companyId);
  FirestoreQueryCache.instance.invalidateCompanyCollection('ushet', companyId);
  FirestoreQueryCache.instance.invalidateCompanyCollection(
    'business_events',
    companyId,
  );
  FirestoreQueryCache.instance.invalidateCompanyCollection(
    PersonalFinanceSupport.entriesCollection,
    companyId,
  );
  FirestoreQueryCache.instance.invalidateCompanyCollection(
    PersonalFinanceSupport.walletsCollection,
    companyId,
  );
  return true;
}
