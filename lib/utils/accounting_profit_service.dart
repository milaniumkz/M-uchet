import '/backend/backend.dart';
import '/utils/accounting_accounts.dart';
import '/utils/income_exclusion_support.dart';
import '/utils/ledger_scope.dart';

class AccountingProfitSnapshot {
  const AccountingProfitSnapshot({
    required this.income,
    required this.expense,
    required this.profit,
    required this.balance,
    required this.incomeBreakdown,
    required this.expenseBreakdown,
  });

  final double income;
  final double expense;
  final double profit;
  final double balance;
  final Map<String, double> incomeBreakdown;
  final Map<String, double> expenseBreakdown;
}

AccountingProfitSnapshot computeProfitSnapshot({
  required Iterable<dynamic> entries,
  required String ledgerFilter,
  bool Function(DateTime? date)? inPeriod,
}) {
  return computeProfitSnapshotForScope(
    entries: entries,
    ledgerScope: ledgerScopeFromLegacyValue(ledgerFilter),
    inPeriod: inPeriod,
  );
}

AccountingProfitSnapshot computeProfitSnapshotForScope({
  required Iterable<dynamic> entries,
  required LedgerScope ledgerScope,
  bool Function(DateTime? date)? inPeriod,
}) {
  final incomeBreakdown = <String, double>{};
  final expenseBreakdown = <String, double>{};
  var income = 0.0;
  var expense = 0.0;

  for (final entry in entries) {
    if (!ledgerScope
        .matches(ledgerScopeFromLegacyValue(_entryLedgerScope(entry)))) {
      continue;
    }
    if (inPeriod != null && !inPeriod(_entryDate(entry))) continue;
    final amount = _entryAmount(entry);
    if (amount <= 0) continue;

    if (accountNatureForId(_creditAccountId(entry)) == AccountNature.income &&
        !isExcludedCompanyIncome(entry) &&
        !isTaxRefundAccountId(_creditAccountId(entry))) {
      income += amount;
      final key = _creditAccountTitle(entry).trim().isEmpty
          ? 'Прочие'
          : _creditAccountTitle(entry).trim();
      incomeBreakdown[key] = (incomeBreakdown[key] ?? 0) + amount;
    }

    if (accountNatureForId(_debitAccountId(entry)) == AccountNature.expense) {
      expense += amount;
      final key = _debitAccountTitle(entry).trim().isEmpty
          ? 'Прочие'
          : _debitAccountTitle(entry).trim();
      expenseBreakdown[key] = (expenseBreakdown[key] ?? 0) + amount;
    }
  }

  if (incomeBreakdown.isEmpty) {
    incomeBreakdown['Прочие'] = 0;
  }
  if (expenseBreakdown.isEmpty) {
    expenseBreakdown['Прочие'] = 0;
  }

  final profit = income - expense;
  return AccountingProfitSnapshot(
    income: income,
    expense: expense,
    profit: profit,
    balance: profit,
    incomeBreakdown: incomeBreakdown,
    expenseBreakdown: expenseBreakdown,
  );
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String _entryLedgerScope(dynamic entry) {
  if (entry is AccountingEntryRecord) return entry.ledgerScope;
  final map = _map(entry);
  return (map['ledger_scope'] ?? map['ledgerScope'] ?? '').toString();
}

DateTime? _entryDate(dynamic entry) {
  if (entry is AccountingEntryRecord) return entry.entryDate;
  final value = _map(entry)['entry_date'];
  if (value is DateTime) return value;
  return null;
}

double _entryAmount(dynamic entry) {
  if (entry is AccountingEntryRecord) return entry.amount;
  final value = _map(entry)['amount'];
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _debitAccountId(dynamic entry) {
  if (entry is AccountingEntryRecord) return entry.debitAccountId;
  return (_map(entry)['debit_account_id'] ?? '').toString();
}

String _creditAccountId(dynamic entry) {
  if (entry is AccountingEntryRecord) return entry.creditAccountId;
  return (_map(entry)['credit_account_id'] ?? '').toString();
}

String _debitAccountTitle(dynamic entry) {
  if (entry is AccountingEntryRecord) return entry.debitAccountTitle;
  return (_map(entry)['debit_account_title'] ?? '').toString();
}

String _creditAccountTitle(dynamic entry) {
  if (entry is AccountingEntryRecord) return entry.creditAccountTitle;
  return (_map(entry)['credit_account_title'] ?? '').toString();
}
