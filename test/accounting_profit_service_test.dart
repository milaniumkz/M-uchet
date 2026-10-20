import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/accounting_entry_service.dart';
import 'package:uchet_s_d/utils/accounting_profit_service.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';

void main() {
  test('computes income and expense from accounting entries by ledger scope',
      () {
    final entries = [
      {
        'entry_date': DateTime(2025, 1, 10),
        'debit_account_id': 'cash-1',
        'credit_account_id': virtualIncomeAccountId(
          ledgerScope: LedgerScope.management,
          category: 'Продажа',
        ),
        'credit_account_title': 'Продажа',
        'amount': 1000.0,
        'ledger_scope': LedgerScope.management.storageValue,
      },
      {
        'entry_date': DateTime(2025, 1, 11),
        'debit_account_id': virtualExpenseAccountId(
          ledgerScope: LedgerScope.management,
          category: 'Топливо',
        ),
        'debit_account_title': 'Топливо',
        'credit_account_id': 'cash-1',
        'amount': 300.0,
        'ledger_scope': LedgerScope.management.storageValue,
      },
      {
        'entry_date': DateTime(2025, 1, 12),
        'debit_account_id': 'cash-1',
        'credit_account_id': virtualIncomeAccountId(
          ledgerScope: LedgerScope.accounting,
          category: 'Продажа',
        ),
        'credit_account_title': 'Продажа',
        'amount': 700.0,
        'ledger_scope': LedgerScope.accounting.storageValue,
      },
    ];

    final management = computeProfitSnapshot(
      entries: entries,
      ledgerFilter: 'Up1',
    );
    final accounting = computeProfitSnapshot(
      entries: entries,
      ledgerFilter: 'Bu',
    );

    expect(management.income, 1000);
    expect(management.expense, 300);
    expect(management.profit, 700);
    expect(management.incomeBreakdown['Продажа'], 1000);
    expect(management.expenseBreakdown['Топливо'], 300);

    expect(accounting.income, 700);
    expect(accounting.expense, 0);
  });

  test('typed ledger scope snapshot matches legacy filter behavior', () {
    final entries = [
      {
        'debit_account_id': 'cash-1',
        'credit_account_id': virtualIncomeAccountId(
          ledgerScope: LedgerScope.management,
          category: 'Продажа',
        ),
        'credit_account_title': 'Продажа',
        'amount': 150.0,
        'ledger_scope': LedgerScope.management.storageValue,
      },
      {
        'debit_account_id': virtualExpenseAccountId(
          ledgerScope: LedgerScope.accounting,
          category: 'Аренда',
        ),
        'debit_account_title': 'Аренда',
        'credit_account_id': 'cash-1',
        'amount': 50.0,
        'ledger_scope': LedgerScope.accounting.storageValue,
      },
    ];

    final typed = computeProfitSnapshotForScope(
      entries: entries,
      ledgerScope: LedgerScope.management,
    );
    final legacy = computeProfitSnapshot(
      entries: entries,
      ledgerFilter: 'Up1',
    );

    expect(typed.income, legacy.income);
    expect(typed.expense, legacy.expense);
    expect(typed.profit, legacy.profit);
  });

  test('tax refund entries are excluded from company income', () {
    final snapshot = computeProfitSnapshotForScope(
      entries: [
        {
          'debit_account_id': 'bank-1',
          'credit_account_id': virtualTaxRefundAccountId(
            ledgerScope: LedgerScope.accounting,
          ),
          'credit_account_title': 'Возврат налога',
          'description': 'Возврат налога',
          'amount': 52562.0,
          'ledger_scope': LedgerScope.accounting.storageValue,
        },
        {
          'debit_account_id': 'bank-1',
          'credit_account_id': virtualIncomeAccountId(
            ledgerScope: LedgerScope.accounting,
            category: 'Продажа',
          ),
          'credit_account_title': 'Продажа',
          'amount': 1000.0,
          'ledger_scope': LedgerScope.accounting.storageValue,
        },
      ],
      ledgerScope: LedgerScope.accounting,
    );

    expect(snapshot.income, 1000);
    expect(snapshot.incomeBreakdown.containsKey('Возврат налога'), isFalse);
  });
}
