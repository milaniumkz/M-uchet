import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/backend.dart';
import '/backend/schema/money_wallet_record.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_wallet_support.dart';

class WalletBalanceSnapshot {
  const WalletBalanceSnapshot({
    required this.walletId,
    required this.currentBalance,
    required this.openingBalance,
    required this.ledgerScope,
  });

  final String walletId;
  final double currentBalance;
  final double openingBalance;
  final LedgerScope ledgerScope;
}

WalletBalanceSnapshot computeWalletBalanceSnapshot({
  required Map<String, dynamic> walletData,
  Map<String, dynamic>? accountData,
  Map<String, dynamic>? cashRegisterData,
}) {
  final walletId = (walletData['id'] ?? walletData['wallet_id'] ?? '').toString();
  final ledgerScope = ledgerScopeFromData(walletData);
  if (accountData != null) {
    return WalletBalanceSnapshot(
      walletId: walletId,
      currentBalance: _num(accountData['summa']),
      openingBalance:
          _num(accountData['opening_balance'] ?? accountData['openingBalance']),
      ledgerScope: ledgerScope,
    );
  }
  if (cashRegisterData != null) {
    return WalletBalanceSnapshot(
      walletId: walletId,
      currentBalance: _num(cashRegisterData['ending_cash']),
      openingBalance: _num(cashRegisterData['opening_cash']),
      ledgerScope: ledgerScope,
    );
  }
  return WalletBalanceSnapshot(
    walletId: walletId,
    currentBalance:
        _num(walletData['current_balance'] ?? walletData['currentBalance']),
    openingBalance:
        _num(walletData['opening_balance'] ?? walletData['openingBalance']),
    ledgerScope: ledgerScope,
  );
}

Future<void> rebuildWalletBalances({
  required FirebaseFirestore firestore,
  required String companyId,
}) async {
  await rebuildCompanyMoneyWallets(firestore: firestore, companyId: companyId);
  final wallets = await queryMoneyWalletRecordOnce(
    queryBuilder: (query) => query.where('idCompany', isEqualTo: companyId),
  );
  final accounts = await queryShetaRecordOnce(
    queryBuilder: (query) => query.where('idCompany', isEqualTo: companyId),
  );
  final accountById = {
    for (final account in accounts) account.reference.id: account.snapshotData,
  };
  final registerSnap = await firestore
      .collection('cash_registers')
      .where('idCompany', isEqualTo: companyId)
      .get();
  final latestRegisterByWalletId = <String, Map<String, dynamic>>{};
  for (final doc in registerSnap.docs) {
    final data = {'id': doc.id, ...doc.data()};
    final walletId = walletDocIdForCashRegister(
      companyId: companyId,
      registerName: (data['cash_register_name'] ?? 'Касса').toString(),
      ledgerScope: ledgerScopeFromData(data),
    );
    latestRegisterByWalletId[walletId] = data;
  }

  final batch = firestore.batch();
  for (final wallet in wallets) {
    final accountData = wallet.linkedLegacyAccountId.isEmpty
        ? null
        : accountById[wallet.linkedLegacyAccountId];
    final cashRegisterData = latestRegisterByWalletId[wallet.reference.id];
    final snapshot = computeWalletBalanceSnapshot(
      walletData: {'id': wallet.reference.id, ...wallet.snapshotData},
      accountData: accountData,
      cashRegisterData: cashRegisterData,
    );
    batch.update(wallet.reference, {
      'current_balance': snapshot.currentBalance,
      'currentBalance': snapshot.currentBalance,
      'opening_balance': snapshot.openingBalance,
      'openingBalance': snapshot.openingBalance,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
}

double _num(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}
