import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/accounting_entry_service.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';
import 'package:uchet_s_d/utils/money_flow_type.dart';
import 'package:uchet_s_d/utils/pnl_report_service.dart';

void main() {
  test('prefers cogs register rows over legacy sale_item_cogs rows', () {
    final rows = resolvePnlCogsItems(
      cogsEntries: [
        {
          'sale_item_id': 'si-1',
          'total_cost': 300.0,
          'ledger_scope': LedgerScope.management.storageValue,
        },
      ],
      legacyCogsItems: [
        {
          'sale_item_id': 'si-1',
          'total_cost': 999.0,
          'ledger_scope': LedgerScope.management.storageValue,
        },
      ],
    );

    expect(rows, hasLength(1));
    expect(rows.single['total_cost'], 300.0);
  });

  test('falls back to legacy sale_item_cogs when cogs register is empty', () {
    final rows = resolvePnlCogsItems(
      cogsEntries: const [],
      legacyCogsItems: [
        {
          'sale_item_id': 'si-1',
          'cogs_amount': 420.0,
          'ledger_scope': LedgerScope.management.storageValue,
        },
      ],
    );

    expect(rows, hasLength(1));
    expect(rows.single['cogs_amount'], 420.0);
  });

  test('computes revenue cogs gross and net profit', () {
    final pnl = computePnlReport(
      entries: [
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
          'money_flow_type': MoneyFlowType.operating.storageValue,
        },
        {
          'entry_date': DateTime(2025, 1, 11),
          'debit_account_id': virtualExpenseAccountId(
            ledgerScope: LedgerScope.management,
            category: 'Аренда',
          ),
          'debit_account_title': 'Аренда',
          'credit_account_id': 'cash-1',
          'amount': 250.0,
          'ledger_scope': LedgerScope.management.storageValue,
          'money_flow_type': MoneyFlowType.operating.storageValue,
        },
      ],
      cogsItems: [
        {
          'created_at': DateTime(2025, 1, 10),
          'total_cost': 400.0,
          'ledger_scope': LedgerScope.management.storageValue,
        },
      ],
      ledgerScope: LedgerScope.management,
    );

    expect(pnl.revenue, 1000);
    expect(pnl.cogs, 400);
    expect(pnl.grossProfit, 600);
    expect(pnl.opex, 250);
    expect(pnl.netProfit, 350);
  });

  test('tax refund entries are not revenue', () {
    final pnl = computePnlReport(
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
          'money_flow_type': MoneyFlowType.operating.storageValue,
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
          'money_flow_type': MoneyFlowType.operating.storageValue,
        },
      ],
      cogsItems: const [],
      ledgerScope: LedgerScope.accounting,
    );

    expect(pnl.revenue, 1000);
    expect(pnl.netProfit, 1000);
    expect(pnl.revenueBreakdown.containsKey('Возврат налога'), isFalse);
  });

  test('does not double count payable settlement after expense accrual', () {
    final payableId = virtualPayableAccountId(
      ledgerScope: LedgerScope.accounting,
      counterparty: 'ИП Media Boost',
    );
    final pnl = computePnlReport(
      entries: [
        {
          'entry_date': DateTime(2026, 5, 25),
          'debit_account_id': virtualExpenseAccountId(
            ledgerScope: LedgerScope.accounting,
            category: 'Маркетинг',
          ),
          'debit_account_title': 'Маркетинг',
          'credit_account_id': payableId,
          'credit_account_title': 'Кредиторка',
          'amount': 1300000.0,
          'ledger_scope': LedgerScope.accounting.storageValue,
          'money_flow_type': MoneyFlowType.operating.storageValue,
        },
        {
          'entry_date': DateTime(2026, 5, 25),
          'debit_account_id': payableId,
          'debit_account_title': 'Кредиторка',
          'credit_account_id': 'bank-1',
          'credit_account_title': 'Forte Bank',
          'amount': 1300000.0,
          'ledger_scope': LedgerScope.accounting.storageValue,
          'money_flow_type': MoneyFlowType.operating.storageValue,
          'description': 'Оплата услуг маркетинга',
          'memo': 'ИП Media Boost',
        },
      ],
      cogsItems: const [],
      ledgerScope: LedgerScope.accounting,
    );

    expect(pnl.opex, 1300000);
    expect(pnl.netProfit, -1300000);
  });

  test('keeps legacy payable settlement as expense when no accrual exists', () {
    final pnl = computePnlReport(
      entries: [
        {
          'entry_date': DateTime(2026, 5, 25),
          'debit_account_id': virtualPayableAccountId(
            ledgerScope: LedgerScope.accounting,
            counterparty: 'ИП Media Boost',
          ),
          'debit_account_title': 'Кредиторка',
          'credit_account_id': 'bank-1',
          'credit_account_title': 'Forte Bank',
          'amount': 1300000.0,
          'ledger_scope': LedgerScope.accounting.storageValue,
          'money_flow_type': MoneyFlowType.operating.storageValue,
          'description': 'Оплата услуг маркетинга',
          'memo': 'ИП Media Boost',
        },
      ],
      cogsItems: const [],
      ledgerScope: LedgerScope.accounting,
    );

    expect(pnl.opex, 1300000);
  });

  test('excludes transfer and financing flows from profit', () {
    final pnl = computePnlReport(
      entries: [
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
          'money_flow_type': MoneyFlowType.operating.storageValue,
        },
        {
          'entry_date': DateTime(2025, 1, 11),
          'debit_account_id': 'bank-1',
          'credit_account_id': 'cash-1',
          'amount': 500.0,
          'ledger_scope': LedgerScope.management.storageValue,
          'money_flow_type': MoneyFlowType.transfer.storageValue,
        },
        {
          'entry_date': DateTime(2025, 1, 12),
          'debit_account_id': 'cash-1',
          'credit_account_id': 'virtual:equity:MANAGEMENT:Вклад собственника',
          'amount': 700.0,
          'ledger_scope': LedgerScope.management.storageValue,
          'money_flow_type': MoneyFlowType.financing.storageValue,
        },
      ],
      cogsItems: const [],
      ledgerScope: LedgerScope.management,
    );

    expect(pnl.revenue, 1000);
    expect(pnl.netProfit, 1000);
  });
}
