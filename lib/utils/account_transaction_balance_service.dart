import 'package:cloud_firestore/cloud_firestore.dart';

class AccountTransactionMovementSummary {
  const AccountTransactionMovementSummary({
    required this.income,
    required this.expense,
    required this.incomeCount,
    required this.expenseCount,
    required this.openingBalance,
    required this.closingBalance,
  });

  final double income;
  final double expense;
  final int incomeCount;
  final int expenseCount;
  final double openingBalance;
  final double closingBalance;
}

AccountTransactionMovementSummary computeAccountTransactionMovementSummary({
  required String accountId,
  required double storedBalance,
  required double openingBalance,
  required bool hasOpeningBalance,
  required Iterable<Map<String, dynamic>> transactionPayloads,
}) {
  var income = 0.0;
  var expense = 0.0;
  var incomeCount = 0;
  var expenseCount = 0;

  for (final transaction in transactionPayloads) {
    final signed = transactionSignedAmountForAccount(
      transaction: transaction,
      accountId: accountId,
    );
    if (signed > 0) {
      income += signed;
      incomeCount++;
    } else if (signed < 0) {
      expense += signed.abs();
      expenseCount++;
    }
  }

  final effectiveOpeningBalance =
      hasOpeningBalance ? openingBalance : storedBalance - income + expense;
  return AccountTransactionMovementSummary(
    income: income,
    expense: expense,
    incomeCount: incomeCount,
    expenseCount: expenseCount,
    openingBalance: effectiveOpeningBalance,
    closingBalance: effectiveOpeningBalance + income - expense,
  );
}

double transactionSignedAmountForAccount({
  required Map<String, dynamic> transaction,
  required String accountId,
}) {
  if (!_transactionTouchesAccount(transaction, accountId)) return 0;
  if (!_transactionIsPosted(transaction)) return 0;

  final type = _str(transaction['type']).toLowerCase();
  final amount = _num(
    transaction['amount_original'] ??
        transaction['amountOriginal'] ??
        transaction['summa'] ??
        transaction['amount'],
  );
  if (amount <= 0) return 0;

  if (type == 'transfer') {
    final sourceId = _documentIdFromValue(
      transaction['sourceSchetId'] ?? transaction['source_schet_id'],
    );
    final targetId = _documentIdFromValue(
      transaction['targetSchetId'] ?? transaction['target_schet_id'],
    );
    final sourceWalletId = _str(
      transaction['from_wallet_id'] ?? transaction['fromWalletId'],
    );
    final targetWalletId = _str(
      transaction['to_wallet_id'] ?? transaction['toWalletId'],
    );
    if (targetId == accountId) return amount;
    if (sourceId == accountId) return -amount;
    if (_walletBelongsToAccount(targetWalletId, accountId)) return amount;
    if (_walletBelongsToAccount(sourceWalletId, accountId)) return -amount;
    return 0;
  }

  final paymentAccountId = _documentIdFromValue(
    transaction['schetId'] ?? transaction['schet_id'],
  );
  final walletId = _str(transaction['wallet_id'] ?? transaction['walletId']);
  if (paymentAccountId != accountId &&
      !_walletBelongsToAccount(walletId, accountId)) {
    return 0;
  }
  if (type == 'income' || type == 'doxod' || type == 'доход') return amount;
  if (type == 'decome' ||
      type == 'expense' ||
      type == 'rashod' ||
      type == 'расход') {
    return -amount;
  }
  return 0;
}

bool _transactionTouchesAccount(
  Map<String, dynamic> transaction,
  String accountId,
) {
  if (_documentIdFromValue(transaction['schetId']) == accountId) return true;
  if (_documentIdFromValue(transaction['schet_id']) == accountId) return true;
  if (_walletBelongsToAccount(
    _str(transaction['wallet_id'] ?? transaction['walletId']),
    accountId,
  )) {
    return true;
  }
  if (_documentIdFromValue(
        transaction['sourceSchetId'] ?? transaction['source_schet_id'],
      ) ==
      accountId) {
    return true;
  }
  if (_documentIdFromValue(
        transaction['targetSchetId'] ?? transaction['target_schet_id'],
      ) ==
      accountId) {
    return true;
  }
  if (_walletBelongsToAccount(
    _str(transaction['from_wallet_id'] ?? transaction['fromWalletId']),
    accountId,
  )) {
    return true;
  }
  if (_walletBelongsToAccount(
    _str(transaction['to_wallet_id'] ?? transaction['toWalletId']),
    accountId,
  )) {
    return true;
  }
  return false;
}

bool _transactionIsPosted(Map<String, dynamic> transaction) {
  final status = _str(transaction['status']).toLowerCase();
  if (status.isEmpty) return true;
  return status == 'posted' ||
      status == 'completed' ||
      status == 'paid' ||
      status == 'проводка' ||
      status == 'проводки' ||
      status == 'проведена' ||
      status == 'проведен' ||
      status == 'проведено' ||
      status == 'проведён';
}

String _documentIdFromValue(dynamic value) {
  if (value is DocumentReference) return value.id;
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return '';
  final slash = raw.split('/').where((part) => part.isNotEmpty).toList();
  return slash.isEmpty ? raw : slash.last;
}

bool _walletBelongsToAccount(String walletId, String accountId) {
  final normalizedWallet = walletId.trim();
  final normalizedAccount = accountId.trim();
  if (normalizedWallet.isEmpty || normalizedAccount.isEmpty) return false;
  return normalizedWallet == 'account_$normalizedAccount';
}

String _str(dynamic value) => value == null ? '' : value.toString().trim();

double _num(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(_str(value).replaceAll(',', '.')) ?? 0.0;
}
