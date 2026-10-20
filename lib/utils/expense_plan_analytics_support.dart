import 'package:cloud_firestore/cloud_firestore.dart';

import '/utils/accounting_accounts.dart';
import '/utils/income_exclusion_support.dart';
import '/utils/ledger_scope.dart';

double expensePlanNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

double expensePlanCompanyAmount(Map<String, dynamic> data) {
  return expensePlanNum(
    data['amount_company'] ??
        data['amountCompany'] ??
        data['amount'] ??
        data['summa'],
  );
}

String expensePlanString(dynamic value) => value?.toString().trim() ?? '';

DateTime? expensePlanDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

Map<String, dynamic> buildExpensePlanPayload({
  required String companyId,
  required String categoryName,
  required String periodKey,
  required double plannedAmount,
  required LedgerScope ledgerScope,
  required String notes,
  required bool isCreate,
}) {
  return <String, dynamic>{
    'idCompany': companyId.trim(),
    'category_name': categoryName.trim(),
    'period_key': periodKey.trim(),
    'planned_amount': plannedAmount,
    ...ledgerScopeFields(ledgerScope: ledgerScope),
    'notes': notes.trim(),
    'updated_at': FieldValue.serverTimestamp(),
    if (isCreate) 'created_at': FieldValue.serverTimestamp(),
  };
}

class ExpensePlanFactRow {
  const ExpensePlanFactRow({
    required this.categoryName,
    required this.periodKey,
    required this.ledgerScope,
    required this.plannedAmount,
    required this.actualAmount,
    required this.previousActualAmount,
  });

  final String categoryName;
  final String periodKey;
  final LedgerScope ledgerScope;
  final double plannedAmount;
  final double actualAmount;
  final double previousActualAmount;

  double get varianceAmount => actualAmount - plannedAmount;
  double get variancePercent => plannedAmount <= 0
      ? (actualAmount > 0 ? 100 : 0)
      : (varianceAmount / plannedAmount) * 100;
  bool get overspend => actualAmount > plannedAmount && plannedAmount > 0;
  bool get underspend => plannedAmount > 0 && actualAmount < plannedAmount;
  bool get hasUnplannedActual => plannedAmount <= 0 && actualAmount > 0;
}

class ExpenseRiskIndicator {
  const ExpenseRiskIndicator({
    required this.categoryName,
    required this.periodKey,
    required this.code,
    required this.message,
    required this.severity,
  });

  final String categoryName;
  final String periodKey;
  final String code;
  final String message;
  final String severity;
}

String periodKeyForDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

double computeBudgetActualNetProfit({
  required double incomeActual,
  required double expenseActual,
}) {
  return incomeActual - expenseActual;
}

List<String> periodKeysForMonths(
  int year,
  List<int> months,
) {
  final normalizedMonths = months.toSet().toList()..sort();
  return normalizedMonths
      .map((month) => '$year-${month.toString().padLeft(2, '0')}')
      .toList(growable: false);
}

List<ExpensePlanFactRow> buildExpensePlanFactRows({
  required List<Map<String, dynamic>> planDocs,
  required List<Map<String, dynamic>> expenseDocs,
  required String periodKey,
  LedgerScope? ledgerScope,
}) {
  final planMap = <String, ExpensePlanFactRow>{};
  for (final doc in planDocs) {
    final rowScope = ledgerScopeFromData(doc);
    if (ledgerScope != null && !rowScope.matches(ledgerScope)) continue;
    final rowPeriod = expensePlanString(doc['period_key']);
    if (rowPeriod != periodKey) continue;
    final categoryName = expensePlanString(doc['category_name']);
    final key = '${rowScope.storageValue}|$categoryName';
    planMap[key] = ExpensePlanFactRow(
      categoryName: categoryName,
      periodKey: rowPeriod,
      ledgerScope: rowScope,
      plannedAmount: expensePlanNum(doc['planned_amount']),
      actualAmount: 0,
      previousActualAmount: 0,
    );
  }

  final currentDate = DateTime.tryParse('$periodKey-01');
  final previousKey = currentDate == null
      ? ''
      : periodKeyForDate(DateTime(currentDate.year, currentDate.month - 1, 1));

  for (final doc in expenseDocs) {
    final rowScope = ledgerScopeFromData(doc);
    if (ledgerScope != null && !rowScope.matches(ledgerScope)) continue;
    final date = expensePlanDate(doc['date']) ??
        expensePlanDate(doc['created_at']) ??
        expensePlanDate(doc['updated_at']);
    if (date == null) continue;
    final rowPeriod = periodKeyForDate(date);
    final categoryName = expensePlanString(doc['category_name']).isEmpty
        ? expensePlanString(doc['kat'])
        : expensePlanString(doc['category_name']);
    if (categoryName.isEmpty) continue;
    final key = '${rowScope.storageValue}|$categoryName';
    final current = planMap[key] ??
        ExpensePlanFactRow(
          categoryName: categoryName,
          periodKey: periodKey,
          ledgerScope: rowScope,
          plannedAmount: 0,
          actualAmount: 0,
          previousActualAmount: 0,
        );
    final amount = expensePlanCompanyAmount(doc).abs();
    if (rowPeriod == periodKey) {
      planMap[key] = ExpensePlanFactRow(
        categoryName: current.categoryName,
        periodKey: current.periodKey,
        ledgerScope: current.ledgerScope,
        plannedAmount: current.plannedAmount,
        actualAmount: current.actualAmount + amount,
        previousActualAmount: current.previousActualAmount,
      );
    } else if (previousKey.isNotEmpty && rowPeriod == previousKey) {
      planMap[key] = ExpensePlanFactRow(
        categoryName: current.categoryName,
        periodKey: current.periodKey,
        ledgerScope: current.ledgerScope,
        plannedAmount: current.plannedAmount,
        actualAmount: current.actualAmount,
        previousActualAmount: current.previousActualAmount + amount,
      );
    }
  }

  final rows = planMap.values.toList();
  rows.sort((a, b) => b.varianceAmount.compareTo(a.varianceAmount));
  return rows;
}

List<ExpensePlanFactRow> buildExpensePlanFactRowsForPeriods({
  required List<Map<String, dynamic>> planDocs,
  required List<Map<String, dynamic>> expenseDocs,
  required List<String> periodKeys,
  LedgerScope? ledgerScope,
}) {
  final merged = <String, ExpensePlanFactRow>{};
  for (final periodKey in periodKeys) {
    final rows = buildExpensePlanFactRows(
      planDocs: planDocs,
      expenseDocs: expenseDocs,
      periodKey: periodKey,
      ledgerScope: ledgerScope,
    );
    for (final row in rows) {
      final key = '${row.ledgerScope.storageValue}|${row.categoryName}';
      final current = merged[key];
      merged[key] = ExpensePlanFactRow(
        categoryName: row.categoryName,
        periodKey: periodKeys.join(','),
        ledgerScope: row.ledgerScope,
        plannedAmount: (current?.plannedAmount ?? 0) + row.plannedAmount,
        actualAmount: (current?.actualAmount ?? 0) + row.actualAmount,
        previousActualAmount:
            (current?.previousActualAmount ?? 0) + row.previousActualAmount,
      );
    }
  }
  final rows = merged.values.toList();
  rows.sort((a, b) => b.varianceAmount.compareTo(a.varianceAmount));
  return rows;
}

List<ExpensePlanFactRow> buildExpensePlanFactRowsFromEvents({
  required List<Map<String, dynamic>> planDocs,
  required List<Map<String, dynamic>> eventDocs,
  required String periodKey,
  LedgerScope? ledgerScope,
}) {
  final expenseDocs = eventDocs
      .where((doc) =>
          expensePlanString(doc['event_type']).toUpperCase() ==
          'EXPENSE_RECORDED')
      .map((doc) => <String, dynamic>{
            ...doc,
            'category_name': expensePlanString(doc['category_name']).isEmpty
                ? expensePlanString(doc['notes'])
                : expensePlanString(doc['category_name']),
            'amount': expensePlanNum(doc['cost']),
            'date': doc['occurred_at'] ?? doc['created_at'],
          })
      .toList(growable: false);
  return buildExpensePlanFactRows(
    planDocs: planDocs,
    expenseDocs: expenseDocs,
    periodKey: periodKey,
    ledgerScope: ledgerScope,
  );
}

List<Map<String, dynamic>> buildBudgetExpenseActualDocs({
  required List<Map<String, dynamic>> transactions,
  required List<Map<String, dynamic>> accountingEntries,
}) {
  return buildBudgetActualDocs(
    transactions: transactions,
    accountingEntries: accountingEntries,
  ).where((doc) => expensePlanString(doc['type']) == 'decome').toList();
}

List<Map<String, dynamic>> buildBudgetActualDocs({
  required List<Map<String, dynamic>> transactions,
  required List<Map<String, dynamic>> accountingEntries,
}) {
  final docs = <Map<String, dynamic>>[];

  for (final tx in transactions) {
    final entryIds = tx['entry_ids'];
    if (entryIds is Iterable && entryIds.isNotEmpty) {
      continue;
    }
    final type = expensePlanString(tx['type']).toLowerCase();
    final isIncome = type == 'income' || type == 'доход' || type == 'doxod';
    final isExpense = type == 'decome' ||
        type == 'expense' ||
        type == 'расход' ||
        type == 'rashod';
    if (!isIncome && !isExpense) continue;
    if (isIncome && isExcludedCompanyIncome(tx)) continue;
    docs.add(<String, dynamic>{
      ...tx,
      'type': isIncome ? 'income' : 'decome',
      'category_name': _normalizeBudgetCategoryTitle(
        expensePlanString(tx['category_name']).isEmpty
            ? expensePlanString(tx['kat'])
            : expensePlanString(tx['category_name']),
        isIncome ? 'income' : 'decome',
      ),
      'amount': expensePlanCompanyAmount(tx).abs(),
      'date': tx['date'] ?? tx['created_at'] ?? tx['updated_at'],
    });
  }

  for (final entry in accountingEntries) {
    final type = _budgetEntryType(entry);
    if (type.isEmpty) continue;
    docs.add(<String, dynamic>{
      ...entry,
      'type': type,
      'category_name': _normalizeBudgetCategoryTitle(
        type == 'income'
            ? _entryIncomeCategory(entry)
            : _entryExpenseCategory(entry),
        type,
      ),
      'amount': expensePlanNum(entry['amount']),
      'date': entry['entry_date'] ?? entry['date'] ?? entry['created_at'],
    });
  }

  return docs;
}

String _budgetEntryType(Map<String, dynamic> entry) {
  final flowType =
      expensePlanString(entry['money_flow_type'] ?? entry['moneyFlowType'])
          .toUpperCase();
  if (flowType == 'TRANSFER' || flowType == 'INVESTING') return '';
  final debitId =
      expensePlanString(entry['debit_account_id'] ?? entry['debitAccountId']);
  final debitTitle = expensePlanString(
          entry['debit_account_title'] ?? entry['debitAccountTitle'])
      .toLowerCase();
  final creditId =
      expensePlanString(entry['credit_account_id'] ?? entry['creditAccountId']);
  if (accountNatureForId(creditId) == AccountNature.income &&
      !isExcludedCompanyIncome(entry) &&
      !isTaxRefundAccountId(creditId)) {
    return 'income';
  }
  if (accountNatureForId(debitId) == AccountNature.expense ||
      debitId.startsWith('virtual:liability:payable:') ||
      debitTitle == 'кредиторка' ||
      debitTitle == 'кредиторская задолженность') {
    return 'decome';
  }
  return '';
}

String _entryIncomeCategory(Map<String, dynamic> entry) {
  for (final value in [
    entry['category_name'],
    entry['budget_category'],
  ]) {
    final title = expensePlanString(value);
    if (title.isNotEmpty) return title;
  }
  final fromAccountId = _virtualAccountCategory(
    entry['credit_account_id'] ?? entry['creditAccountId'],
    'virtual:income:',
  );
  if (fromAccountId.isNotEmpty) return fromAccountId;
  for (final value in [
    entry['credit_account_title'],
    entry['creditAccountTitle'],
    entry['description'],
  ]) {
    final title = expensePlanString(value);
    if (title.isNotEmpty && !_isGenericIncomeTitle(title)) return title;
  }
  return 'Доход от основной деятельности';
}

String _normalizeBudgetCategoryTitle(String title, String type) {
  final trimmed = title.trim();
  final normalized = trimmed.toLowerCase();
  if (type == 'income') {
    if (normalized.isEmpty || _isGenericIncomeTitle(trimmed)) {
      return 'Доход от основной деятельности';
    }
    if (normalized.contains('неоснов')) {
      return 'Доход от неосновной деятельности';
    }
    if (normalized.contains('проч')) {
      return 'Прочие доходы';
    }
    if (normalized.contains('основ')) {
      return 'Доход от основной деятельности';
    }
  }
  if (type == 'decome' && normalized.contains('маркетинг')) {
    return 'Маркетинг (всё включено)';
  }
  return trimmed;
}

bool _isGenericIncomeTitle(String title) {
  final normalized = title.trim().toLowerCase();
  return normalized == 'income' ||
      normalized == 'doxod' ||
      normalized == 'доход' ||
      normalized == 'доходы' ||
      normalized == 'выручка' ||
      normalized == 'general';
}

String _virtualAccountCategory(dynamic accountId, String prefix) {
  final id = expensePlanString(accountId);
  if (!id.startsWith(prefix)) return '';
  final parts = id.split(':');
  if (parts.length < 4) return '';
  return parts.sublist(3).join(':').trim();
}

String _entryExpenseCategory(Map<String, dynamic> entry) {
  for (final value in [
    entry['category_name'],
    entry['budget_category'],
    entry['debit_account_title'],
    entry['description'],
  ]) {
    final title = expensePlanString(value);
    if (title.isNotEmpty &&
        title.toLowerCase() != 'кредиторка' &&
        title.toLowerCase() != 'кредиторская задолженность') {
      return _normalizeBudgetCategoryTitle(title, 'decome');
    }
  }
  return 'Расход';
}

List<ExpenseRiskIndicator> buildExpenseRiskIndicators(
  List<ExpensePlanFactRow> rows, {
  double overspendThresholdPercent = 20,
  double criticalThresholdPercent = 50,
  double growthThresholdPercent = 30,
}) {
  final indicators = <ExpenseRiskIndicator>[];
  for (final row in rows) {
    if (row.hasUnplannedActual) {
      indicators.add(
        ExpenseRiskIndicator(
          categoryName: row.categoryName,
          periodKey: row.periodKey,
          code: 'UNPLANNED_ACTUAL',
          message: 'Есть факт без плана',
          severity: 'high',
        ),
      );
    }
    if (row.overspend) {
      indicators.add(
        ExpenseRiskIndicator(
          categoryName: row.categoryName,
          periodKey: row.periodKey,
          code: 'OVERSPEND',
          message: 'План превышен',
          severity: row.variancePercent >= criticalThresholdPercent
              ? 'critical'
              : 'medium',
        ),
      );
    }
    if (row.plannedAmount > 0 &&
        row.variancePercent >= overspendThresholdPercent) {
      indicators.add(
        ExpenseRiskIndicator(
          categoryName: row.categoryName,
          periodKey: row.periodKey,
          code: 'THRESHOLD_EXCEEDED',
          message: 'Отклонение выше порога',
          severity: row.variancePercent >= criticalThresholdPercent
              ? 'critical'
              : 'medium',
        ),
      );
    }
    if (row.previousActualAmount > 0) {
      final growth = ((row.actualAmount - row.previousActualAmount) /
              row.previousActualAmount) *
          100;
      if (growth >= growthThresholdPercent) {
        indicators.add(
          ExpenseRiskIndicator(
            categoryName: row.categoryName,
            periodKey: row.periodKey,
            code: 'SHARP_GROWTH',
            message: 'Резкий рост расходов к прошлому периоду',
            severity:
                growth >= criticalThresholdPercent ? 'critical' : 'medium',
          ),
        );
      }
    }
  }
  return indicators;
}
