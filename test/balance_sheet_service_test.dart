import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uchet_s_d/utils/balance_sheet_service.dart';
import 'package:uchet_s_d/utils/debt_register_support.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';

void main() {
  test(
      'balance sheet balances cash inventory receivables against liabilities and equity',
      () {
    final debts = [
      DebtRecordView.fromMap({
        'id': 'ar1',
        'type': 'AR',
        'remaining_amount': 200,
        'total_amount': 200,
        'ledger_scope': 'management',
      }),
      DebtRecordView.fromMap({
        'id': 'ap1',
        'type': 'AP',
        'remaining_amount': 150,
        'total_amount': 150,
        'ledger_scope': 'management',
        'source_document_id': 'ob-1',
      }),
    ];
    final sheet = computeBalanceSheet(
      wallets: [
        {
          'current_balance': 500,
          'ledger_scope': LedgerScope.management.storageValue,
        }
      ],
      inventoryBatches: [
        {
          'total_cost': 100,
          'ledger_scope': LedgerScope.management.storageValue,
        }
      ],
      debts: debts,
      obligations: const [],
      accountingEntries: [
        {
          'credit_account_id': 'virtual:equity:owner_capital',
          'debit_account_id': 'wallet:cash',
          'amount': 300,
          'ledger_scope': LedgerScope.management.storageValue,
        },
        {
          'credit_account_id': 'virtual:income:sales',
          'debit_account_id': 'wallet:cash',
          'credit_account_title': 'Sales',
          'amount': 350,
          'ledger_scope': LedgerScope.management.storageValue,
        }
      ],
      cogsItems: const [
        {
          'cogs_amount': 0,
          'ledger_scope': 'management',
        }
      ],
      ledgerScope: LedgerScope.management,
    );

    expect(sheet.assetsTotal, 800);
    expect(sheet.liabilitiesTotal, 150);
    expect(sheet.ownerCapitalTotal, 300);
    expect(sheet.retainedEarningsTotal, 350);
    expect(sheet.equityTotal, 650);
    expect(sheet.isBalanced, isTrue);
  });

  test(
      'legacy obligations without debt record are included as liabilities fallback',
      () {
    final sheet = computeBalanceSheet(
      wallets: const [],
      inventoryBatches: const [],
      debts: const [],
      obligations: [
        {
          'id': 'ob-legacy',
          'amount': 400,
          'total_paid': 150,
          'ledger_scope': LedgerScope.management.storageValue,
        }
      ],
      accountingEntries: const [],
      cogsItems: const [],
      ledgerScope: LedgerScope.management,
    );

    expect(sheet.loansTotal, 250);
    expect(sheet.liabilitiesTotal, 250);
  });

  test('cash total prefers account balances over stale wallet balances', () {
    final sheet = computeBalanceSheet(
      wallets: [
        {
          'current_balance': 1086727,
          'ledger_scope': LedgerScope.accounting.storageValue,
        }
      ],
      accounts: [
        {
          'id': 'forte',
          'title': 'Forte Bank',
          'account_type': 'asset',
          'opening_balance': 519818,
          'opening_balance_date': DateTime(2026, 7, 24),
          'ledger_scope': LedgerScope.accounting.storageValue,
        }
      ],
      inventoryBatches: const [],
      debts: const [],
      obligations: const [],
      accountingEntries: [
        {
          'debit_account_id': 'forte',
          'credit_account_id': 'virtual:income:ACCOUNTING:general',
          'amount': 2300000,
          'entry_date': DateTime(2026, 7, 24),
          'ledger_scope': LedgerScope.accounting.storageValue,
        },
        {
          'debit_account_id': 'virtual:expense:ACCOUNTING:Маркетинг',
          'credit_account_id': 'forte',
          'amount': 1300000,
          'entry_date': DateTime(2026, 7, 24),
          'ledger_scope': LedgerScope.accounting.storageValue,
        },
        {
          'debit_account_id': 'forte',
          'credit_account_id': 'virtual:tax_refund:ACCOUNTING',
          'amount': 86727,
          'entry_date': DateTime(2026, 7, 24),
          'ledger_scope': LedgerScope.accounting.storageValue,
        },
      ],
      cogsItems: const [],
      ledgerScope: LedgerScope.accounting,
    );

    expect(sheet.cashTotal, 1606545);
  });

  test('uses cogs register rows when provided instead of legacy cogs items',
      () {
    final sheet = computeBalanceSheet(
      wallets: const [],
      inventoryBatches: const [],
      debts: const [],
      obligations: const [],
      accountingEntries: [
        {
          'credit_account_id': 'virtual:income:sales',
          'debit_account_id': 'wallet:cash',
          'credit_account_title': 'Sales',
          'amount': 1000,
          'ledger_scope': LedgerScope.management.storageValue,
        }
      ],
      cogsEntries: const [
        {
          'total_cost': 250,
          'ledger_scope': 'management',
        }
      ],
      legacyCogsItems: const [
        {
          'cogs_amount': 800,
          'ledger_scope': 'management',
        }
      ],
      ledgerScope: LedgerScope.management,
    );

    expect(sheet.retainedEarningsTotal, 750);
  });

  test('balance retained earnings respect firestore timestamp-backed pnl rows',
      () {
    final sheet = computeBalanceSheet(
      wallets: const [],
      inventoryBatches: const [],
      debts: const [],
      obligations: const [],
      accountingEntries: [
        {
          'credit_account_id': 'virtual:income:sales',
          'debit_account_id': 'wallet:cash',
          'credit_account_title': 'Sales',
          'amount': 500,
          'ledger_scope': LedgerScope.management.storageValue,
          'created_at': Timestamp.fromDate(DateTime(2025, 8, 1)),
        }
      ],
      cogsItems: const [],
      ledgerScope: LedgerScope.management,
    );

    expect(sheet.retainedEarningsTotal, 500);
  });
}
