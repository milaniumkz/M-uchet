import '/backend/backend.dart';
import '/utils/accounting_accounts.dart';
import '/utils/income_exclusion_support.dart';
import '/utils/ledger_scope.dart';

class AccountBalanceRow {
  const AccountBalanceRow({
    required this.accountRef,
    required this.accountId,
    required this.title,
    required this.ledgerScope,
    required this.nature,
    required this.openingBalance,
    required this.debitTurnover,
    required this.creditTurnover,
    required this.closingBalance,
  });

  final DocumentReference accountRef;
  final String accountId;
  final String title;
  final LedgerScope ledgerScope;
  final AccountNature nature;
  final double openingBalance;
  final double debitTurnover;
  final double creditTurnover;
  final double closingBalance;
}

class AccountBalanceSummary {
  const AccountBalanceSummary({
    required this.rows,
    required this.assets,
    required this.liabilities,
    required this.equity,
    required this.income,
    required this.expenses,
  });

  final List<AccountBalanceRow> rows;
  final double assets;
  final double liabilities;
  final double equity;
  final double income;
  final double expenses;
}

class SingleAccountBalanceSnapshot {
  const SingleAccountBalanceSnapshot({
    required this.debitTurnover,
    required this.creditTurnover,
    required this.closingBalance,
  });

  final double debitTurnover;
  final double creditTurnover;
  final double closingBalance;
}

AccountBalanceSummary computeAccountBalanceSummary({
  required List<ShetaRecord> accounts,
  required List<Map<String, dynamic>> entryPayloads,
}) {
  final debitByAccount = <String, double>{};
  final creditByAccount = <String, double>{};
  double income = 0.0;
  double expenses = 0.0;

  for (final entry in entryPayloads) {
    final amount = _num(entry['amount']);
    if (amount <= 0) continue;
    final debitId = (entry['debit_account_id'] ?? '').toString().trim();
    final creditId = (entry['credit_account_id'] ?? '').toString().trim();
    if (debitId.isNotEmpty) {
      debitByAccount[debitId] = (debitByAccount[debitId] ?? 0) + amount;
      if (accountNatureForId(debitId) == AccountNature.expense) {
        expenses += amount;
      }
    }
    if (creditId.isNotEmpty) {
      creditByAccount[creditId] = (creditByAccount[creditId] ?? 0) + amount;
      if (accountNatureForId(creditId) == AccountNature.income &&
          !isExcludedCompanyIncome(entry) &&
          !isTaxRefundAccountId(creditId)) {
        income += amount;
      }
    }
  }

  final rows = <AccountBalanceRow>[];
  double assets = 0.0;
  double liabilities = 0.0;
  double equity = 0.0;

  for (final account in accounts) {
    final accountId = account.reference.id;
    final accountTurnovers = _turnoversForAccountAfterOpeningDate(
      account: account,
      entryPayloads: entryPayloads,
    );
    final opening = _openingBalanceFor(
      account,
      {accountId: accountTurnovers.debitTurnover},
      {accountId: accountTurnovers.creditTurnover},
    );
    final debitTurnover = accountTurnovers.debitTurnover;
    final creditTurnover = accountTurnovers.creditTurnover;
    final nature = account.accountNature;
    final closing = closingBalanceForNature(
      nature: nature,
      openingBalance: opening,
      debitTurnover: debitTurnover,
      creditTurnover: creditTurnover,
    );
    final row = AccountBalanceRow(
      accountRef: account.reference,
      accountId: accountId,
      title: account.title,
      ledgerScope: account.ledgerScopeEnum,
      nature: nature,
      openingBalance: opening,
      debitTurnover: debitTurnover,
      creditTurnover: creditTurnover,
      closingBalance: closing,
    );
    rows.add(row);

    switch (nature) {
      case AccountNature.asset:
        assets += closing;
        break;
      case AccountNature.liability:
        liabilities += closing;
        break;
      case AccountNature.equity:
        equity += closing;
        break;
      case AccountNature.income:
      case AccountNature.expense:
        break;
    }
  }

  return AccountBalanceSummary(
    rows: rows,
    assets: assets,
    liabilities: liabilities,
    equity: equity,
    income: income,
    expenses: expenses,
  );
}

Future<AccountBalanceSummary> loadAccountBalanceSummary({
  required FirebaseFirestore firestore,
  required String companyId,
}) async {
  final accounts = await queryShetaRecordOnce(
    queryBuilder: (query) => query.where('idCompany', isEqualTo: companyId),
  );
  final entrySnap = await firestore
      .collection('accounting_entries')
      .where('idCompany', isEqualTo: companyId)
      .get();
  final entries = entrySnap.docs.map((doc) => doc.data()).toList();
  return computeAccountBalanceSummary(
      accounts: accounts, entryPayloads: entries);
}

SingleAccountBalanceSnapshot computeSingleAccountBalance({
  required String accountId,
  required AccountNature nature,
  required double openingBalance,
  required List<Map<String, dynamic>> entryPayloads,
  DateTime? openingBalanceDate,
}) {
  var debitTurnover = 0.0;
  var creditTurnover = 0.0;
  for (final entry in entryPayloads) {
    final amount = _num(entry['amount']);
    if (amount <= 0) continue;
    if (_isBeforeOpeningBalanceDate(entry, openingBalanceDate)) continue;
    if ((entry['debit_account_id'] ?? '').toString().trim() == accountId) {
      debitTurnover += amount;
    }
    if ((entry['credit_account_id'] ?? '').toString().trim() == accountId) {
      creditTurnover += amount;
    }
  }
  return SingleAccountBalanceSnapshot(
    debitTurnover: debitTurnover,
    creditTurnover: creditTurnover,
    closingBalance: closingBalanceForNature(
      nature: nature,
      openingBalance: openingBalance,
      debitTurnover: debitTurnover,
      creditTurnover: creditTurnover,
    ),
  );
}

_AccountTurnovers _turnoversForAccountAfterOpeningDate({
  required ShetaRecord account,
  required List<Map<String, dynamic>> entryPayloads,
}) {
  final accountId = account.reference.id;
  var debitTurnover = 0.0;
  var creditTurnover = 0.0;
  for (final entry in entryPayloads) {
    final amount = _num(entry['amount']);
    if (amount <= 0) continue;
    if (_isBeforeOpeningBalanceDate(entry, account.openingBalanceDate)) {
      continue;
    }
    if ((entry['debit_account_id'] ?? '').toString().trim() == accountId) {
      debitTurnover += amount;
    }
    if ((entry['credit_account_id'] ?? '').toString().trim() == accountId) {
      creditTurnover += amount;
    }
  }
  return _AccountTurnovers(
    debitTurnover: debitTurnover,
    creditTurnover: creditTurnover,
  );
}

bool _isBeforeOpeningBalanceDate(
  Map<String, dynamic> entry,
  DateTime? openingBalanceDate,
) {
  final entryDate = _date(entry['entry_date'] ?? entry['date']);
  return isEntryDateBeforeOpeningBalanceDate(
    entryDate: entryDate,
    openingBalanceDate: openingBalanceDate,
  );
}

bool isEntryDateBeforeOpeningBalanceDate({
  required DateTime? entryDate,
  required DateTime? openingBalanceDate,
}) {
  if (openingBalanceDate == null || entryDate == null) return false;
  final entryDay = DateTime(entryDate.year, entryDate.month, entryDate.day);
  final openingDay = DateTime(
    openingBalanceDate.year,
    openingBalanceDate.month,
    openingBalanceDate.day,
  );
  return entryDay.isBefore(openingDay);
}

class _AccountTurnovers {
  const _AccountTurnovers({
    required this.debitTurnover,
    required this.creditTurnover,
  });

  final double debitTurnover;
  final double creditTurnover;
}

double _openingBalanceFor(
  ShetaRecord account,
  Map<String, double> debitByAccount,
  Map<String, double> creditByAccount,
) {
  if (account.hasOpeningBalance()) {
    return account.openingBalance;
  }
  final debit = debitByAccount[account.reference.id] ?? 0.0;
  final credit = creditByAccount[account.reference.id] ?? 0.0;
  final net = closingBalanceForNature(
    nature: account.accountNature,
    openingBalance: 0,
    debitTurnover: debit,
    creditTurnover: credit,
  );
  return account.summa - net;
}

double _num(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return null;
}
