import '/utils/accounting_accounts.dart';
import '/utils/debt_register_support.dart';
import '/utils/ledger_scope.dart';
import '/utils/pnl_report_service.dart';

class BalanceSheet {
  const BalanceSheet({
    required this.cashTotal,
    required this.inventoryTotal,
    required this.receivablesTotal,
    required this.payablesTotal,
    required this.loansTotal,
    required this.ownerCapitalTotal,
    required this.openingAdjustmentTotal,
    required this.retainedEarningsTotal,
  });

  final double cashTotal;
  final double inventoryTotal;
  final double receivablesTotal;
  final double payablesTotal;
  final double loansTotal;
  final double ownerCapitalTotal;
  final double openingAdjustmentTotal;
  final double retainedEarningsTotal;

  double get assetsTotal => cashTotal + inventoryTotal + receivablesTotal;
  double get liabilitiesTotal => payablesTotal + loansTotal;
  double get equityTotal =>
      ownerCapitalTotal + openingAdjustmentTotal + retainedEarningsTotal;
  double get imbalance => assetsTotal - (liabilitiesTotal + equityTotal);
  bool get isBalanced => imbalance.abs() <= 0.01;
}

BalanceSheet computeBalanceSheet({
  required List<Map<String, dynamic>> wallets,
  List<Map<String, dynamic>> accounts = const [],
  required List<Map<String, dynamic>> inventoryBatches,
  required List<DebtRecordView> debts,
  required List<Map<String, dynamic>> obligations,
  required List<Map<String, dynamic>> accountingEntries,
  List<Map<String, dynamic>> cogsItems = const [],
  List<Map<String, dynamic>> cogsEntries = const [],
  List<Map<String, dynamic>> legacyCogsItems = const [],
  LedgerScope? ledgerScope,
}) {
  final resolvedCogsItems = cogsItems.isNotEmpty
      ? cogsItems
      : resolvePnlCogsItems(
          cogsEntries: cogsEntries,
          legacyCogsItems: legacyCogsItems,
        );
  final walletCash = accounts.isNotEmpty
      ? _cashFromAccounts(
          accounts: accounts,
          entries: accountingEntries,
          ledgerScope: ledgerScope,
        )
      : wallets
          .where((wallet) => _scopeMatches(wallet, ledgerScope))
          .fold<double>(0, (total, wallet) {
          final balance = _toNum(
            wallet['current_balance'] ?? wallet['currentBalance'] ?? 0,
          );
          return total + balance;
        });

  final inventory = inventoryBatches
      .where((batch) => _scopeMatches(batch, ledgerScope))
      .fold<double>(0, (total, batch) {
    final totalCost = _toNum(batch['total_cost']);
    if (totalCost > 0) {
      return total + totalCost;
    }
    final qty = _toNum(batch['qty_remaining']);
    final unitCost = _toNum(batch['unit_cost']);
    return total + (qty * unitCost);
  });

  final scopedDebts = debts
      .where((debt) =>
          ledgerScope == null || debt.ledgerScope.matches(ledgerScope))
      .toList();
  final receivables = scopedDebts
      .where((debt) => debt.type == DebtType.ar && debt.isOpen)
      .fold<double>(0, (total, debt) => total + debt.remainingAmount);
  final payables = scopedDebts
      .where((debt) => debt.type == DebtType.ap && debt.isOpen)
      .fold<double>(0, (total, debt) => total + debt.remainingAmount);

  final debtSourceIds = scopedDebts
      .map((debt) => debt.sourceDocumentId)
      .where((id) => id.isNotEmpty)
      .toSet();
  final legacyLoans = obligations
      .where((item) => _scopeMatches(item, ledgerScope))
      .where((item) => !debtSourceIds.contains((item['id'] ?? '').toString()))
      .fold<double>(0, (total, item) {
    final amount = _toNum(item['amount']);
    final paid = _toNum(item['total_paid']);
    final remaining = amount - paid;
    return total + (remaining > 0 ? remaining : 0);
  });

  var ownerCapital = 0.0;
  for (final entry in accountingEntries) {
    if (ledgerScope != null &&
        !ledgerScopeFromLegacyValue(
          (entry['ledger_scope'] ??
                  entry['ledgerScope'] ??
                  entry['typeUchet'] ??
                  '')
              .toString(),
        ).matches(ledgerScope)) {
      continue;
    }
    final amount = _toNum(entry['amount']);
    final debitAccountId =
        (entry['debit_account_id'] ?? entry['debitAccountId'] ?? '').toString();
    final creditAccountId =
        (entry['credit_account_id'] ?? entry['creditAccountId'] ?? '')
            .toString();
    if (accountNatureForId(creditAccountId) == AccountNature.equity) {
      ownerCapital += amount;
    }
    if (accountNatureForId(debitAccountId) == AccountNature.equity) {
      ownerCapital -= amount;
    }
  }

  final pnl = computePnlReport(
    entries: accountingEntries,
    cogsItems: resolvedCogsItems,
    ledgerScope: ledgerScope ?? LedgerScope.both,
  );

  final assetsTotal = walletCash + inventory + receivables;
  final liabilitiesTotal = payables + legacyLoans;
  final retainedEarnings = pnl.netProfit;
  final openingAdjustment = accounts.isEmpty
      ? 0.0
      : assetsTotal - (liabilitiesTotal + ownerCapital + retainedEarnings);

  return BalanceSheet(
    cashTotal: walletCash,
    inventoryTotal: inventory,
    receivablesTotal: receivables,
    payablesTotal: payables,
    loansTotal: legacyLoans,
    ownerCapitalTotal: ownerCapital,
    openingAdjustmentTotal:
        openingAdjustment.abs() <= 0.01 ? 0.0 : openingAdjustment,
    retainedEarningsTotal: retainedEarnings,
  );
}

double _cashFromAccounts({
  required List<Map<String, dynamic>> accounts,
  required List<Map<String, dynamic>> entries,
  required LedgerScope? ledgerScope,
}) {
  return accounts
      .where((account) => _scopeMatches(account, ledgerScope))
      .where((account) =>
          accountNatureFromValue(
            (account['account_type'] ?? account['accountType']).toString(),
            tip: account['tip']?.toString(),
          ) ==
          AccountNature.asset)
      .fold<double>(0, (total, account) {
    final accountId = (account['id'] ?? account['account_id'] ?? '').toString();
    if (accountId.isEmpty) return total;
    final openingBalance = _accountOpeningBalance(account, entries, accountId);
    var debit = 0.0;
    var credit = 0.0;
    for (final entry in entries) {
      final amount = _toNum(entry['amount']);
      if ((entry['debit_account_id'] ?? '').toString() == accountId) {
        debit += amount;
      }
      if ((entry['credit_account_id'] ?? '').toString() == accountId) {
        credit += amount;
      }
    }
    return total + openingBalance + debit - credit;
  });
}

double _accountOpeningBalance(
  Map<String, dynamic> account,
  List<Map<String, dynamic>> entries,
  String accountId,
) {
  final rawOpening = account['opening_balance'] ?? account['openingBalance'];
  if (rawOpening != null) return _toNum(rawOpening);
  final current = _toNum(
    account['summa_company'] ??
        account['summaCompany'] ??
        account['balance_company'] ??
        account['balanceCompany'] ??
        account['summa'] ??
        account['balance'],
  );
  var debit = 0.0;
  var credit = 0.0;
  for (final entry in entries) {
    final amount = _toNum(entry['amount']);
    if ((entry['debit_account_id'] ?? '').toString() == accountId) {
      debit += amount;
    }
    if ((entry['credit_account_id'] ?? '').toString() == accountId) {
      credit += amount;
    }
  }
  return current - debit + credit;
}

bool _scopeMatches(Map<String, dynamic> data, LedgerScope? filter) {
  if (filter == null) return true;
  return ledgerScopeFromData(data).matches(filter);
}

double _toNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}
