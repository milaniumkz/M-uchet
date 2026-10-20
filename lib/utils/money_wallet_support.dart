import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/backend.dart';
import '/backend/schema/money_wallet_record.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_wallet_types.dart';

String _slugifyWalletPart(String raw) {
  final normalized = raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9а-яё]+', caseSensitive: false), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return normalized.isEmpty ? 'wallet' : normalized;
}

String walletDocIdForLegacyAccount(String accountId) =>
    'account_${accountId.trim()}';

String walletDocIdForCashRegister({
  required String companyId,
  required String registerName,
  required LedgerScope ledgerScope,
}) {
  return 'cashbox_${companyId.trim()}_${_slugifyWalletPart(registerName)}_${ledgerScope.storageValue.toLowerCase()}';
}

WalletType walletTypeFromLegacyAccount({
  required String? tip,
  String? ownerKind,
}) {
  return walletTypeFromValue(
    null,
    legacyTip: tip,
    ownerKind: ownerKind,
  );
}

Map<String, dynamic> walletFields({
  required String walletId,
  required String walletName,
  required WalletType walletType,
  required LedgerScope ledgerScope,
}) {
  return <String, dynamic>{
    'wallet_id': walletId,
    'walletId': walletId,
    'wallet_name': walletName,
    'walletName': walletName,
    'wallet_type': walletType.storageValue,
    'walletType': walletType.storageValue,
    'wallet_ledger_scope': ledgerScope.storageValue,
    'walletLedgerScope': ledgerScope.storageValue,
  };
}

Map<String, dynamic> transferWalletFields({
  required String fromWalletId,
  required String fromWalletName,
  required String toWalletId,
  required String toWalletName,
}) {
  return <String, dynamic>{
    'from_wallet_id': fromWalletId,
    'fromWalletId': fromWalletId,
    'from_wallet_name': fromWalletName,
    'fromWalletName': fromWalletName,
    'to_wallet_id': toWalletId,
    'toWalletId': toWalletId,
    'to_wallet_name': toWalletName,
    'toWalletName': toWalletName,
  };
}

bool walletMatchesFilters({
  required Map<String, dynamic> walletData,
  WalletType? type,
  LedgerScope? ledgerScope,
}) {
  final walletType = walletTypeFromValue(
    (walletData['type'] ?? walletData['wallet_type']).toString(),
  );
  final walletScope = ledgerScopeFromData(walletData);
  final typeMatches = type == null || walletType == type;
  final ledgerMatches =
      ledgerScope == null || walletScope.matches(ledgerScope);
  return typeMatches && ledgerMatches;
}

Map<String, dynamic> buildMoneyWalletDataFromAccount({
  required ShetaRecord account,
}) {
  return buildMoneyWalletDataFromAccountMap(
    accountId: account.reference.id,
    accountData: account.snapshotData,
    fallbackName: account.title,
    fallbackCompanyId: account.idCompany,
    fallbackComment: account.coment,
    fallbackBalance: account.summa,
    fallbackOpeningBalance: account.openingBalance,
    fallbackLedgerScope: account.ledgerScopeEnum,
  );
}

Map<String, dynamic> buildMoneyWalletDataFromAccountMap({
  required String accountId,
  required Map<String, dynamic> accountData,
  String? fallbackName,
  String? fallbackCompanyId,
  String? fallbackComment,
  double? fallbackBalance,
  double? fallbackOpeningBalance,
  LedgerScope? fallbackLedgerScope,
}) {
  final walletType = walletTypeFromLegacyAccount(
    tip: (accountData['tip'] ?? '').toString(),
    ownerKind: (accountData['ownerKind'] ?? '').toString(),
  );
  return createMoneyWalletRecordData(
    name: (fallbackName ?? (accountData['title'] ?? '').toString()).trim().isEmpty
        ? 'Счет'
        : (fallbackName ?? (accountData['title'] ?? '').toString()).trim(),
    type: walletType.storageValue,
    ledgerScope: (fallbackLedgerScope ?? ledgerScopeFromData(accountData)).storageValue,
    currency: normalizeWalletCurrency(
      (accountData['currency'] ?? '').toString(),
    ),
    isActive: (accountData['isActive'] ?? true) == true,
    openingBalance: fallbackOpeningBalance ??
        _num(accountData['opening_balance'] ?? accountData['openingBalance']),
    currentBalance: fallbackBalance ?? _num(accountData['summa']),
    ownerType: 'company',
    ownerId: fallbackCompanyId ?? (accountData['idCompany'] ?? '').toString(),
    linkedLegacyAccountId: accountId,
    linkedLegacyCardId:
        walletType == WalletType.card ? accountId : null,
    description: fallbackComment ?? (accountData['coment'] ?? '').toString(),
    idCompany: fallbackCompanyId ?? (accountData['idCompany'] ?? '').toString(),
    legacySourceKey: (accountData['tip'] ?? '').toString(),
    updatedAt: FieldValue.serverTimestamp(),
  );
}

Map<String, dynamic> buildMoneyWalletDataFromCashRegister({
  required String walletId,
  required Map<String, dynamic> registerData,
}) {
  final companyId = (registerData['idCompany'] ?? '').toString().trim();
  final registerName =
      (registerData['cash_register_name'] ?? 'Касса').toString().trim();
  final ledgerScope = ledgerScopeFromData(registerData);
  final currentBalance = _num(registerData['ending_cash']);
  final openingBalance = _num(registerData['opening_cash']);
  return createMoneyWalletRecordData(
    name: registerName.isEmpty ? 'Касса' : registerName,
    type: WalletType.cashbox.storageValue,
    ledgerScope: ledgerScope.storageValue,
    currency: normalizeWalletCurrency(
      (registerData['currency'] ?? 'KZT').toString(),
    ),
    isActive: (registerData['closed_at'] == null),
    openingBalance: openingBalance,
    currentBalance: currentBalance,
    ownerType: 'company',
    ownerId: companyId,
    linkedLegacyCashboxId: (registerData['id'] ?? '').toString(),
    description: (registerData['note'] ?? '').toString(),
    idCompany: companyId,
    legacySourceKey: _slugifyWalletPart(registerName),
    updatedAt: FieldValue.serverTimestamp(),
  );
}

Future<MoneyWalletRecord?> ensureWalletForAccountReference({
  required FirebaseFirestore firestore,
  required DocumentReference? accountRef,
  String? fallbackTitle,
}) async {
  if (accountRef == null) return null;
  final snap = await accountRef.get();
  if (!snap.exists) return null;
  final account = ShetaRecord.fromSnapshot(snap);
  return ensureWalletForAccountRecord(
    firestore: firestore,
    account: account,
    fallbackTitle: fallbackTitle,
  );
}

Future<MoneyWalletRecord> ensureWalletForAccountRecord({
  required FirebaseFirestore firestore,
  required ShetaRecord account,
  String? fallbackTitle,
}) async {
  final walletRef =
      firestore.collection(MoneyWalletRecord.collection.path).doc(
            walletDocIdForLegacyAccount(account.reference.id),
          );
  final base = buildMoneyWalletDataFromAccount(account: account);
  await walletRef.set({
    ...base,
    if ((base['name'] ?? '').toString().trim().isEmpty && fallbackTitle != null)
      'name': fallbackTitle,
    'created_at': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
  return MoneyWalletRecord.getDocumentFromData({
    'id': walletRef.id,
    ...base,
  }, walletRef);
}

Future<MoneyWalletRecord> ensureWalletForCashRegister({
  required FirebaseFirestore firestore,
  required Map<String, dynamic> registerData,
}) async {
  final walletRef =
      firestore.collection(MoneyWalletRecord.collection.path).doc(
            walletDocIdForCashRegister(
              companyId: (registerData['idCompany'] ?? '').toString(),
              registerName:
                  (registerData['cash_register_name'] ?? 'Касса').toString(),
              ledgerScope: ledgerScopeFromData(registerData),
            ),
          );
  final base = buildMoneyWalletDataFromCashRegister(
    walletId: walletRef.id,
    registerData: registerData,
  );
  await walletRef.set({
    ...base,
    'created_at': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
  return MoneyWalletRecord.getDocumentFromData({
    'id': walletRef.id,
    ...base,
  }, walletRef);
}

Future<List<Map<String, dynamic>>> listCompanyWalletOptions({
  required FirebaseFirestore firestore,
  required String companyId,
  WalletType? type,
  LedgerScope? ledgerScope,
}) async {
  final accounts = await queryShetaRecordOnce(
    queryBuilder: (query) => query.where('idCompany', isEqualTo: companyId),
  );
  for (final account in accounts) {
    await ensureWalletForAccountRecord(firestore: firestore, account: account);
  }

  final registersSnap = await firestore
      .collection('cash_registers')
      .where('idCompany', isEqualTo: companyId)
      .get();
  final latestRegisters = <String, Map<String, dynamic>>{};
  for (final doc in registersSnap.docs) {
    final data = {'id': doc.id, ...doc.data()};
    final walletId = walletDocIdForCashRegister(
      companyId: companyId,
      registerName: (data['cash_register_name'] ?? 'Касса').toString(),
      ledgerScope: ledgerScopeFromData(data),
    );
    final current = latestRegisters[walletId];
    final currentDate = _date(current?['updated_at'] ?? current?['opened_at']);
    final nextDate = _date(data['updated_at'] ?? data['opened_at']);
    if (current == null ||
        (nextDate != null &&
            (currentDate == null || nextDate.isAfter(currentDate)))) {
      latestRegisters[walletId] = data;
    }
  }
  for (final register in latestRegisters.values) {
    await ensureWalletForCashRegister(
      firestore: firestore,
      registerData: register,
    );
  }

  final wallets = await queryMoneyWalletRecordOnce(
    queryBuilder: (query) => query.where('idCompany', isEqualTo: companyId),
  );
  final rows = wallets
      .where((wallet) {
        return walletMatchesFilters(
          walletData: wallet.snapshotData,
          type: type,
          ledgerScope: ledgerScope,
        );
      })
      .map((wallet) => {
            'id': wallet.reference.id,
            ...wallet.snapshotData,
          })
      .toList();
  rows.sort((a, b) =>
      (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
  return rows;
}

Future<void> rebuildCompanyMoneyWallets({
  required FirebaseFirestore firestore,
  required String companyId,
}) async {
  if (companyId.trim().isEmpty) return;
  await listCompanyWalletOptions(
    firestore: firestore,
    companyId: companyId,
  );
}

String? legacyWalletIdFromTransactionData(Map<String, dynamic> data) {
  final explicit = (data['wallet_id'] ?? data['walletId'] ?? '').toString().trim();
  if (explicit.isNotEmpty) return explicit;
  final schetId = data['schetId'];
  if (schetId is DocumentReference) {
    return walletDocIdForLegacyAccount(schetId.id);
  }
  final rawSchetId = (data['schet_id'] ?? '').toString().trim();
  if (rawSchetId.isNotEmpty) {
    return walletDocIdForLegacyAccount(rawSchetId);
  }
  return null;
}

double _num(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
