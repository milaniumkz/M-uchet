import '/backend/backend.dart';
import '/utils/accounting_accounts.dart';
import '/utils/income_exclusion_support.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_flow_type.dart';

class PnlReport {
  const PnlReport({
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.opex,
    required this.netProfit,
    required this.revenueBreakdown,
    required this.opexBreakdown,
  });

  final double revenue;
  final double cogs;
  final double grossProfit;
  final double opex;
  final double netProfit;
  final Map<String, double> revenueBreakdown;
  final Map<String, double> opexBreakdown;
}

List<Map<String, dynamic>> resolvePnlCogsItems({
  required Iterable<Map<String, dynamic>> cogsEntries,
  required Iterable<Map<String, dynamic>> legacyCogsItems,
}) {
  final normalizedEntries = cogsEntries
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
  if (normalizedEntries.isNotEmpty) {
    return normalizedEntries;
  }
  return legacyCogsItems
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

PnlReport computePnlReport({
  required Iterable<dynamic> entries,
  required Iterable<dynamic> cogsItems,
  required LedgerScope ledgerScope,
  bool Function(DateTime? date)? inPeriod,
}) {
  final revenueBreakdown = <String, double>{};
  final opexBreakdown = <String, double>{};
  var revenue = 0.0;
  var cogs = 0.0;
  var opex = 0.0;
  final accruedPayableExpenseKeys = entries
      .where(_isPayableExpenseAccrual)
      .map(_payableAccrualKey)
      .where((key) => key.isNotEmpty)
      .toSet();

  for (final entry in entries) {
    if (!ledgerScope
        .matches(ledgerScopeFromLegacyValue(_entryLedgerScope(entry)))) {
      continue;
    }
    if (inPeriod != null && !inPeriod(_entryDate(entry))) continue;
    final amount = _entryAmount(entry);
    if (amount <= 0) continue;
    final flowType = _entryMoneyFlowType(entry);
    final isLegacyOperatingPayableExpense =
        _isLegacyOperatingPayableExpense(entry) &&
            !accruedPayableExpenseKeys.contains(_payableSettlementKey(entry));
    if (flowType == MoneyFlowType.transfer ||
        flowType == MoneyFlowType.investing ||
        (flowType == MoneyFlowType.financing &&
            !isLegacyOperatingPayableExpense)) {
      continue;
    }

    if (accountNatureForId(_creditAccountId(entry)) == AccountNature.income &&
        !isExcludedCompanyIncome(entry) &&
        !isTaxRefundAccountId(_creditAccountId(entry))) {
      revenue += amount;
      final key = _creditAccountTitle(entry).trim().isEmpty
          ? 'Прочие'
          : _creditAccountTitle(entry).trim();
      revenueBreakdown[key] = (revenueBreakdown[key] ?? 0) + amount;
    }

    if (accountNatureForId(_debitAccountId(entry)) == AccountNature.expense ||
        isLegacyOperatingPayableExpense) {
      opex += amount;
      final key = _opexLabel(entry);
      opexBreakdown[key] = (opexBreakdown[key] ?? 0) + amount;
    }
  }

  for (final item in cogsItems) {
    if (!ledgerScope
        .matches(ledgerScopeFromLegacyValue(_cogsLedgerScope(item)))) {
      continue;
    }
    if (inPeriod != null && !inPeriod(_cogsDate(item))) continue;
    cogs += _cogsAmount(item);
  }

  if (revenueBreakdown.isEmpty) {
    revenueBreakdown['Прочие'] = 0;
  }
  if (opexBreakdown.isEmpty) {
    opexBreakdown['Прочие'] = 0;
  }

  final grossProfit = revenue - cogs;
  final netProfit = grossProfit - opex;
  return PnlReport(
    revenue: revenue,
    cogs: cogs,
    grossProfit: grossProfit,
    opex: opex,
    netProfit: netProfit,
    revenueBreakdown: revenueBreakdown,
    opexBreakdown: opexBreakdown,
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
  if (entry is AccountingEntryRecord) {
    return entry.entryDate ?? entry.createdAt ?? entry.updatedAt;
  }
  final map = _map(entry);
  final value = map['entry_date'] ?? map['created_at'] ?? map['updated_at'];
  if (value is Timestamp) return value.toDate();
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

String _entryDescription(dynamic entry) {
  if (entry is AccountingEntryRecord) return entry.description;
  final map = _map(entry);
  return (map['description'] ?? map['text'] ?? '').toString();
}

String _entryMemo(dynamic entry) {
  if (entry is AccountingEntryRecord) return entry.memo;
  final map = _map(entry);
  return (map['memo'] ?? map['counterparty'] ?? '').toString();
}

bool _isLegacyOperatingPayableExpense(dynamic entry) {
  final debitId = _debitAccountId(entry);
  final debitTitle = _debitAccountTitle(entry).trim().toLowerCase();
  final isPayableDebit = debitId.startsWith('virtual:liability:payable:') ||
      debitTitle == 'кредиторка' ||
      debitTitle == 'кредиторская задолженность';
  if (!isPayableDebit) return false;
  final combined = [
    _entryDescription(entry),
    _entryMemo(entry),
  ].join(' ').toLowerCase();
  const financingMarkers = [
    'займ',
    'кредит',
    'капитал',
    'вклад',
    'собствен',
    'loan',
    'credit',
    'capital',
  ];
  return !financingMarkers.any(combined.contains);
}

bool _isPayableExpenseAccrual(dynamic entry) {
  return accountNatureForId(_debitAccountId(entry)) == AccountNature.expense &&
      _creditAccountId(entry).startsWith('virtual:liability:payable:');
}

String _payableAccrualKey(dynamic entry) {
  final creditId = _creditAccountId(entry);
  if (!creditId.startsWith('virtual:liability:payable:')) return '';
  return [
    _entryLedgerScope(entry),
    creditId,
    _entryAmount(entry).toStringAsFixed(2),
  ].join('|');
}

String _payableSettlementKey(dynamic entry) {
  final debitId = _debitAccountId(entry);
  if (!debitId.startsWith('virtual:liability:payable:')) return '';
  return [
    _entryLedgerScope(entry),
    debitId,
    _entryAmount(entry).toStringAsFixed(2),
  ].join('|');
}

String _opexLabel(dynamic entry) {
  if (_isLegacyOperatingPayableExpense(entry)) {
    final description = _entryDescription(entry).trim();
    final memo = _entryMemo(entry).trim();
    if (description.isNotEmpty) return description;
    if (memo.isNotEmpty) return memo;
    return 'Обязательства';
  }
  final debitTitle = _debitAccountTitle(entry).trim();
  return debitTitle.isEmpty ? 'Прочие' : debitTitle;
}

MoneyFlowType _entryMoneyFlowType(dynamic entry) {
  if (entry is AccountingEntryRecord) return entry.moneyFlowTypeEnum;
  final map = _map(entry);
  return inferMoneyFlowType(
    explicitValue: (map['money_flow_type'] ?? map['moneyFlowType'])?.toString(),
    transactionType: map['type']?.toString(),
    category: map['kat']?.toString(),
    description: map['description']?.toString() ?? map['text']?.toString(),
    obligationId: map['obligationId']?.toString(),
  );
}

String _cogsLedgerScope(dynamic item) {
  final map = _map(item);
  return (map['ledger_scope'] ?? map['ledgerScope'] ?? '').toString();
}

DateTime? _cogsDate(dynamic item) {
  final map = _map(item);
  final value = map['created_at'] ?? map['date'] ?? map['updated_at'];
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

double _cogsAmount(dynamic item) {
  final map = _map(item);
  final value = map['total_cost'] ?? map['cogs_amount'] ?? map['cost_amount'];
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
