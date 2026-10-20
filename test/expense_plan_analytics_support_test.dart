import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/expense_plan_analytics_support.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';

void main() {
  test('builds expense plan vs actual rows and variance', () {
    final rows = buildExpensePlanFactRows(
      planDocs: [
        {
          'category_name': 'Маркетинг',
          'period_key': '2025-08',
          'planned_amount': 1000,
          'ledger_scope': 'ACCOUNTING',
        },
      ],
      expenseDocs: [
        {
          'kat': 'Маркетинг',
          'summa': 1500,
          'date': DateTime(2025, 8, 10),
          'ledger_scope': 'ACCOUNTING',
        },
        {
          'kat': 'Маркетинг',
          'summa': 1000,
          'date': DateTime(2025, 7, 10),
          'ledger_scope': 'ACCOUNTING',
        },
      ],
      periodKey: '2025-08',
    );

    expect(rows, hasLength(1));
    expect(rows.first.actualAmount, 1500);
    expect(rows.first.varianceAmount, 500);
    expect(rows.first.variancePercent, 50);
  });

  test('detects risk indicators', () {
    const row = ExpensePlanFactRow(
      categoryName: 'Маркетинг',
      periodKey: '2025-08',
      ledgerScope: LedgerScope.accounting,
      plannedAmount: 1000,
      actualAmount: 1700,
      previousActualAmount: 1000,
    );
    final indicators = buildExpenseRiskIndicators([row]);
    expect(indicators.any((item) => item.code == 'OVERSPEND'), isTrue);
    expect(indicators.any((item) => item.code == 'THRESHOLD_EXCEEDED'), isTrue);
    expect(indicators.any((item) => item.code == 'SHARP_GROWTH'), isTrue);
  });

  test('builds expense plan vs actual rows from business events', () {
    final rows = buildExpensePlanFactRowsFromEvents(
      planDocs: [
        {
          'category_name': 'Маркетинг',
          'period_key': '2025-08',
          'planned_amount': 1000,
          'ledger_scope': 'ACCOUNTING',
        },
      ],
      eventDocs: [
        {
          'event_type': 'EXPENSE_RECORDED',
          'category_name': 'Маркетинг',
          'cost': 1500,
          'occurred_at': DateTime(2025, 8, 10),
          'ledger_scope': 'ACCOUNTING',
        },
        {
          'event_type': 'EXPENSE_RECORDED',
          'category_name': 'Маркетинг',
          'cost': 1000,
          'occurred_at': DateTime(2025, 7, 10),
          'ledger_scope': 'ACCOUNTING',
        },
      ],
      periodKey: '2025-08',
    );

    expect(rows, hasLength(1));
    expect(rows.first.actualAmount, 1500);
    expect(rows.first.previousActualAmount, 1000);
    expect(rows.first.varianceAmount, 500);
  });

  test('builds expense actual docs from accounting entries without duplicates',
      () {
    final actualDocs = buildBudgetExpenseActualDocs(
      transactions: [
        {
          'id': 'tx-with-entry',
          'type': 'decome',
          'kat': 'Маркетинг',
          'summa': 1500,
          'entry_ids': ['entry-1'],
          'date': DateTime(2025, 8, 10),
          'ledger_scope': 'ACCOUNTING',
        },
        {
          'id': 'legacy-tx',
          'type': 'decome',
          'kat': 'Аренда',
          'summa': 700,
          'date': DateTime(2025, 8, 10),
          'ledger_scope': 'ACCOUNTING',
        },
      ],
      accountingEntries: [
        {
          'id': 'entry-1',
          'source_id': 'tx-with-entry',
          'amount': 1500,
          'debit_account_id': 'virtual:expense:Маркетинг',
          'debit_account_title': 'Маркетинг',
          'entry_date': DateTime(2025, 8, 10),
          'ledger_scope': 'ACCOUNTING',
        },
      ],
    );

    final rows = buildExpensePlanFactRows(
      planDocs: const [],
      expenseDocs: actualDocs,
      periodKey: '2025-08',
    );

    expect(rows.fold<double>(0, (sum, row) => sum + row.actualAmount), 2200);
    expect(
      rows.any((row) => row.categoryName == 'Маркетинг (всё включено)'),
      isTrue,
    );
    expect(rows.any((row) => row.categoryName == 'Аренда'), isTrue);
  });

  test('builds income and expense actual docs from whole system', () {
    final actualDocs = buildBudgetActualDocs(
      transactions: [
        {
          'id': 'tx-with-entry',
          'type': 'income',
          'kat': 'Доход от основной деятельности',
          'summa': 1000,
          'entry_ids': ['entry-income'],
          'date': DateTime(2025, 8, 10),
          'ledger_scope': 'ACCOUNTING',
        },
        {
          'id': 'legacy-expense',
          'type': 'decome',
          'kat': 'Маркетинг',
          'summa': 300,
          'date': DateTime(2025, 8, 10),
          'ledger_scope': 'ACCOUNTING',
        },
      ],
      accountingEntries: [
        {
          'id': 'entry-income',
          'amount': 1000,
          'credit_account_id':
              'virtual:income:ACCOUNTING:Доход от основной деятельности',
          'credit_account_title': 'Доход от основной деятельности',
          'entry_date': DateTime(2025, 8, 10),
          'ledger_scope': 'ACCOUNTING',
        },
      ],
    );

    expect(actualDocs.where((doc) => doc['type'] == 'income'), hasLength(1));
    expect(actualDocs.where((doc) => doc['type'] == 'decome'), hasLength(1));
    expect(
      actualDocs
          .where((doc) => doc['type'] == 'income')
          .fold<double>(0, (sum, doc) => sum + expensePlanNum(doc['amount'])),
      1000,
    );
  });

  test('maps income accounting entry category from virtual account id', () {
    final actualDocs = buildBudgetActualDocs(
      transactions: const [],
      accountingEntries: [
        {
          'id': 'entry-income',
          'amount': 2300000,
          'credit_account_id':
              'virtual:income:ACCOUNTING:Доход от основной деятельности',
          'credit_account_title': 'Доходы',
          'entry_date': DateTime(2026, 5, 25),
          'ledger_scope': 'ACCOUNTING',
        },
      ],
    );

    final rows = buildExpensePlanFactRows(
      planDocs: [
        {
          'category_name': 'Доход от основной деятельности',
          'period_key': '2026-05',
          'planned_amount': 0,
          'ledger_scope': 'ACCOUNTING',
        },
      ],
      expenseDocs: actualDocs,
      periodKey: '2026-05',
    );

    expect(
        actualDocs.single['category_name'], 'Доход от основной деятельности');
    expect(rows, hasLength(1));
    expect(rows.single.actualAmount, 2300000);
  });

  test('tax refund is excluded from budget income actuals', () {
    final actualDocs = buildBudgetActualDocs(
      transactions: [
        {
          'id': 'legacy-tax-refund',
          'type': 'income',
          'kat': 'Возврат налога',
          'summa': 52562,
          'date': DateTime(2025, 8, 10),
          'ledger_scope': 'ACCOUNTING',
        },
      ],
      accountingEntries: [
        {
          'id': 'entry-tax-refund',
          'amount': 10512,
          'credit_account_id': 'virtual:tax_refund:ACCOUNTING',
          'credit_account_title': 'Возврат налога',
          'description': 'Возврат налога',
          'entry_date': DateTime(2025, 8, 10),
          'ledger_scope': 'ACCOUNTING',
        },
      ],
    );

    expect(actualDocs.where((doc) => doc['type'] == 'income'), isEmpty);
  });

  test('maps marketing service expenses to default marketing budget category',
      () {
    final actualDocs = buildBudgetActualDocs(
      transactions: [
        {
          'id': 'marketing-service',
          'type': 'decome',
          'kat': 'Маркетинговые услуги',
          'summa': 1300,
          'date': DateTime(2025, 8, 10),
          'ledger_scope': 'ACCOUNTING',
        },
      ],
      accountingEntries: const [],
    );

    expect(actualDocs, hasLength(1));
    expect(actualDocs.first['category_name'], 'Маркетинг (всё включено)');
    expect(expensePlanNum(actualDocs.first['amount']), 1300);
  });

  test('budget actual net profit does not subtract tax expenses twice', () {
    final result = computeBudgetActualNetProfit(
      incomeActual: 1000,
      expenseActual: 300,
    );

    expect(result, 700);
  });
}
