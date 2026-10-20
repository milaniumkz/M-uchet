import 'package:uchet_s_d/backend/schema/accounting_entry_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/account_balance_service.dart';
import 'package:uchet_s_d/utils/accounting_accounts.dart';
import 'package:uchet_s_d/utils/accounting_entry_service.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';
import 'package:uchet_s_d/utils/money_flow_type.dart';

void main() {
  group('buildEntriesForTransactionData', () {
    test('creates debit/credit entry for income transaction', () {
      final drafts = buildEntriesForTransactionData(
        transactionId: 'tx1',
        transactionData: {
          'idCompany': 'c1',
          'type': 'income',
          'kat': 'Продажа',
          'summa': 1500,
          'nds': true,
          'summaNds': 180,
          'schet_id': 'cash-1',
          'schetTitle': 'Касса',
          'ledger_scope': LedgerScope.accounting.storageValue,
        },
      );

      expect(drafts, hasLength(1));
      expect(drafts.single.debitAccountId, 'cash-1');
      expect(
          drafts.single.creditAccountId,
          virtualIncomeAccountId(
              ledgerScope: LedgerScope.accounting, category: 'Продажа'));
      expect(drafts.single.amount, 1500);
      expect(drafts.single.taxKind, 'vat_output');
      expect(drafts.single.taxAmount, 180);
    });

    test('creates entries for Russian posted status', () {
      final drafts = buildEntriesForTransactionData(
        transactionId: 'tx-ru-posted',
        transactionData: {
          'idCompany': 'c1',
          'type': 'income',
          'kat': 'Продажа',
          'summa': 1500,
          'schet_id': 'cash-1',
          'ledger_scope': LedgerScope.accounting.storageValue,
          'status': 'Проведена',
        },
      );

      expect(drafts, hasLength(1));
      expect(drafts.single.debitAccountId, 'cash-1');
    });

    test('uses 16 percent VAT by default for explicit VAT income', () {
      final drafts = buildEntriesForTransactionData(
        transactionId: 'tx-default-vat',
        transactionData: {
          'idCompany': 'c1',
          'type': 'income',
          'kat': 'Продажа',
          'summa': 1000,
          'nds': true,
          'taxable': true,
          'schet_id': 'cash-1',
          'ledger_scope': LedgerScope.accounting.storageValue,
        },
      );

      expect(drafts.single.taxRate, 0.16);
      expect(drafts.single.taxAmount, 160);
    });

    test('taxable income without VAT does not create VAT metadata', () {
      final drafts = buildEntriesForTransactionData(
        transactionId: 'tx-taxable-no-vat',
        transactionData: {
          'idCompany': 'c1',
          'type': 'income',
          'kat': 'Продажа',
          'summa': 1000,
          'nds': false,
          'taxable': true,
          'schet_id': 'cash-1',
          'ledger_scope': LedgerScope.accounting.storageValue,
        },
      );

      expect(drafts.single.taxable, isTrue);
      expect(drafts.single.taxKind, isNull);
      expect(drafts.single.taxAmount, 0);
    });

    test('creates receivable debit entry for debt sale income transaction', () {
      final drafts = buildEntriesForTransactionData(
        transactionId: 'tx-ar-1',
        transactionData: {
          'idCompany': 'c1',
          'type': 'income',
          'kat': 'Продажа',
          'text': 'Продажа (в долг)',
          'summa': 2200,
          'receivable_debt_id': 'debt-ar-sale-1',
          'counterparty': 'Client A',
          'ledger_scope': LedgerScope.management.storageValue,
          'money_flow_type': MoneyFlowType.operating.storageValue,
        },
      );

      expect(drafts, hasLength(1));
      expect(
        drafts.single.debitAccountId,
        virtualReceivableAccountId(
          ledgerScope: LedgerScope.management,
          counterparty: 'Client A',
        ),
      );
      expect(drafts.single.debitAccountTitle, 'Дебиторка');
      expect(
        drafts.single.creditAccountId,
        virtualIncomeAccountId(
          ledgerScope: LedgerScope.management,
          category: 'Продажа',
        ),
      );
      expect(drafts.single.moneyFlowType, MoneyFlowType.operating);
      expect(drafts.single.amount, 2200);
    });

    test('creates receivable settlement entry for client payment', () {
      final drafts = buildEntriesForTransactionData(
        transactionId: 'tx-ar-pay-1',
        transactionData: {
          'idCompany': 'c1',
          'type': 'income',
          'kat': 'Погашение дебиторки',
          'text': 'Оплата от клиента',
          'summa': 1200,
          'schet_id': 'cash-1',
          'schetTitle': 'Касса',
          'counterparty': 'Client A',
          'settles_receivable': true,
          'ledger_scope': LedgerScope.management.storageValue,
          'money_flow_type': MoneyFlowType.operating.storageValue,
        },
      );

      expect(drafts, hasLength(1));
      expect(drafts.single.debitAccountId, 'cash-1');
      expect(
        drafts.single.creditAccountId,
        virtualReceivableAccountId(
          ledgerScope: LedgerScope.management,
          counterparty: 'Client A',
        ),
      );
      expect(drafts.single.creditAccountTitle, 'Дебиторка');
      expect(drafts.single.amount, 1200);
    });

    test('tax refund increases account balance but is excluded from income',
        () {
      final drafts = buildEntriesForTransactionData(
        transactionId: 'tx-tax-refund-1',
        transactionData: {
          'idCompany': 'c1',
          'type': 'income',
          'kat': 'Прочие доходы',
          'text': 'Возврат налога',
          'summa': 10512,
          'schet_id': 'bank-1',
          'schetTitle': 'Банк',
          'ledger_scope': LedgerScope.accounting.storageValue,
        },
      );

      expect(drafts, hasLength(1));
      expect(drafts.single.debitAccountId, 'bank-1');
      expect(
        drafts.single.creditAccountId,
        virtualTaxRefundAccountId(ledgerScope: LedgerScope.accounting),
      );
      expect(
        accountNatureForId(drafts.single.creditAccountId),
        isNot(AccountNature.income),
      );
    });

    test('creates debit/credit entry for expense transaction', () {
      final drafts = buildEntriesForTransactionData(
        transactionId: 'tx2',
        transactionData: {
          'idCompany': 'c1',
          'type': 'decome',
          'kat': 'Топливо',
          'summa': 500,
          'schet_id': 'bank-1',
          'schetTitle': 'Банк',
          'ledger_scope': LedgerScope.management.storageValue,
        },
      );

      expect(
          drafts.single.debitAccountId,
          virtualExpenseAccountId(
              ledgerScope: LedgerScope.management, category: 'Топливо'));
      expect(drafts.single.creditAccountId, 'bank-1');
    });

    test('deductible expense creates input VAT metadata', () {
      final drafts = buildEntriesForTransactionData(
        transactionId: 'tx-vat-input',
        transactionData: {
          'idCompany': 'c1',
          'type': 'decome',
          'kat': 'Маркетинговые услуги',
          'summa': 1000,
          'deductible': true,
          'schet_id': 'bank-1',
          'schetTitle': 'Банк',
          'ledger_scope': LedgerScope.accounting.storageValue,
        },
      );

      expect(drafts.single.taxKind, 'vat_input');
      expect(drafts.single.deductible, isTrue);
      expect(drafts.single.taxRate, 0.16);
      expect(drafts.single.taxAmount, 160);
    });

    test('deductible expense preserves explicit input VAT amount', () {
      final drafts = buildEntriesForTransactionData(
        transactionId: 'tx-vat-input-explicit',
        transactionData: {
          'idCompany': 'c1',
          'type': 'decome',
          'kat': 'Маркетинговые услуги',
          'summa': 1000,
          'summaNds': 120,
          'deductible': true,
          'schet_id': 'bank-1',
          'schetTitle': 'Банк',
          'ledger_scope': LedgerScope.accounting.storageValue,
        },
      );

      expect(drafts.single.taxKind, 'vat_input');
      expect(drafts.single.taxAmount, 120);
    });

    test('creates payable settlement entry for obligation payment', () {
      final drafts = buildEntriesForTransactionData(
        transactionId: 'tx-ap-1',
        transactionData: {
          'idCompany': 'c1',
          'type': 'decome',
          'kat': 'Обязательства',
          'text': 'Оплата обязательства',
          'summa': 900,
          'schet_id': 'bank-1',
          'schetTitle': 'Банк',
          'counterparty': 'Supplier A',
          'obligationId': 'obl-1',
          'ledger_scope': LedgerScope.management.storageValue,
          'money_flow_type': MoneyFlowType.operating.storageValue,
        },
      );

      expect(drafts, hasLength(1));
      expect(
        drafts.single.debitAccountId,
        virtualPayableAccountId(
          ledgerScope: LedgerScope.management,
          counterparty: 'Supplier A',
        ),
      );
      expect(drafts.single.debitAccountTitle, 'Кредиторка');
      expect(drafts.single.creditAccountId, 'bank-1');
      expect(drafts.single.moneyFlowType, MoneyFlowType.operating);
      expect(drafts.single.amount, 900);
    });

    test('creates expense accrual entry for obligation', () {
      final draft = buildEntryForObligationData(
        obligationId: 'obl-marketing',
        obligationData: {
          'idCompany': 'c1',
          'title': 'Услуги маркетинга',
          'category_name': 'Маркетинг (всё включено)',
          'counterparty': 'ИП Media Boost',
          'amount': 1300000,
          'ledger_scope': LedgerScope.accounting.storageValue,
        },
      );

      expect(
        draft.debitAccountId,
        virtualExpenseAccountId(
          ledgerScope: LedgerScope.accounting,
          category: 'Маркетинг (всё включено)',
        ),
      );
      expect(
        draft.creditAccountId,
        virtualPayableAccountId(
          ledgerScope: LedgerScope.accounting,
          counterparty: 'ИП Media Boost',
        ),
      );
      expect(draft.sourceType, 'obligation');
      expect(draft.amount, 1300000);
    });

    test('does not create entries for unposted obligation payment', () {
      final drafts = buildEntriesForTransactionData(
        transactionId: 'tx-ap-draft',
        transactionData: {
          'idCompany': 'c1',
          'type': 'decome',
          'kat': 'Аренда / инфраструктура',
          'text': 'Оплата обязательства',
          'summa': 900,
          'schet_id': 'bank-1',
          'schetTitle': 'Банк',
          'counterparty': 'Supplier A',
          'obligationId': 'obl-1',
          'ledger_scope': LedgerScope.management.storageValue,
          'status': 'Не проведена',
        },
      );

      expect(drafts, isEmpty);
    });

    test('creates transfer entry between accounts', () {
      final drafts = buildEntriesForTransactionData(
        transactionId: 'tx3',
        transactionData: {
          'idCompany': 'c1',
          'type': 'transfer',
          'summa': 700,
          'source_schet_id': 'cash-1',
          'target_schet_id': 'bank-1',
          'ledger_scope': LedgerScope.accounting.storageValue,
        },
      );

      expect(drafts.single.debitAccountId, 'bank-1');
      expect(drafts.single.creditAccountId, 'cash-1');
    });

    test(
        'legacy transaction without stored entries can be rebuilt from transaction data',
        () {
      final drafts = buildEntriesForTransactionData(
        transactionId: 'legacy-tx',
        transactionData: {
          'idCompany': 'c1',
          'type': 'income',
          'kat': 'Прочее',
          'summa': 250,
          'schet_id': 'cash-1',
          'typeUchet': 'Bu',
        },
      );

      expect(drafts.single.debitAccountId, 'cash-1');
      expect(drafts.single.amount, 250);
    });

    test(
        'owner contribution is classified as financing and does not hit income account',
        () {
      final drafts = buildEntriesForTransactionData(
        transactionId: 'owner-tx',
        transactionData: {
          'idCompany': 'c1',
          'type': 'income',
          'kat': 'Вклад собственника',
          'text': 'Вклад собственника',
          'summa': 1000,
          'schet_id': 'cash-1',
          'ledger_scope': LedgerScope.management.storageValue,
        },
      );

      expect(drafts.single.moneyFlowType, MoneyFlowType.financing);
      expect(
        drafts.single.creditAccountId,
        virtualEquityAccountId(
          ledgerScope: LedgerScope.management,
          category: 'Вклад собственника',
        ),
      );
    });

    test(
        'fallback entry payloads preserve debit credit and amount for legacy read',
        () {
      final payloads = buildFallbackEntryPayloadsForTransaction(
        transactionId: 'legacy-tx',
        transactionData: {
          'idCompany': 'c1',
          'type': 'decome',
          'kat': 'Топливо',
          'summa': 250,
          'schet_id': 'cash-1',
          'typeUchet': 'Bu',
        },
      );

      expect(payloads, hasLength(1));
      expect(payloads.single['transaction_id'], 'legacy-tx');
      expect(
        payloads.single['debit_account_id'],
        virtualExpenseAccountId(
          ledgerScope: LedgerScope.accounting,
          category: 'Топливо',
        ),
      );
      expect(payloads.single['credit_account_id'], 'cash-1');
      expect(payloads.single['amount'], 250);
    });

    test('transactionHasStoredEntryIds detects persisted metadata', () {
      expect(
        transactionHasStoredEntryIds({
          'entry_ids': ['e1'],
        }),
        isTrue,
      );
      expect(
        transactionHasStoredEntryIds(const {
          'entry_ids': <String>[],
        }),
        isFalse,
      );
      expect(
        transactionHasStoredEntryIds(const {}),
        isFalse,
      );
    });
  });

  group('accounting entry validation', () {
    test('rejects accounting entry without debit account', () {
      expect(
        () => createAccountingEntryRecordData(
          transactionId: 'tx1',
          sourceType: 'transaction',
          sourceId: 'tx1',
          entryDate: DateTime(2025, 1, 1),
          debitAccountId: '',
          creditAccountId: 'cash-1',
          amount: 100,
          ledgerScope: LedgerScope.accounting.storageValue,
          idCompany: 'c1',
        ),
        throwsArgumentError,
      );
    });

    test('rejects accounting entry with non-positive amount', () {
      expect(
        () => createAccountingEntryRecordData(
          transactionId: 'tx1',
          sourceType: 'transaction',
          sourceId: 'tx1',
          entryDate: DateTime(2025, 1, 1),
          debitAccountId: 'cash-1',
          creditAccountId: 'income-1',
          amount: 0,
          ledgerScope: LedgerScope.accounting.storageValue,
          idCompany: 'c1',
        ),
        throwsArgumentError,
      );
    });
  });

  group('account balance math', () {
    test('computes balance from debit and credit turnovers', () {
      final balance = closingBalanceForNature(
        nature: AccountNature.asset,
        openingBalance: 1000,
        debitTurnover: 1500,
        creditTurnover: 400,
      );
      expect(balance, 2100);
    });

    test(
        'virtual income and expense accounts drive totals, not direct income-expense sum',
        () {
      final entryPayloads = [
        {
          'debit_account_id': 'cash-1',
          'credit_account_id': virtualIncomeAccountId(
              ledgerScope: LedgerScope.accounting, category: 'Продажа'),
          'amount': 1000.0,
          'ledger_scope': LedgerScope.accounting.storageValue,
        },
        {
          'debit_account_id': virtualExpenseAccountId(
              ledgerScope: LedgerScope.accounting, category: 'Топливо'),
          'credit_account_id': 'cash-1',
          'amount': 300.0,
          'ledger_scope': LedgerScope.accounting.storageValue,
        },
      ];

      final summary = computeAccountBalanceSummary(
        accounts: const [],
        entryPayloads: entryPayloads,
      );

      expect(summary.income, 1000);
      expect(summary.expenses, 300);
    });

    test('computes balance for multiple postings on one account', () {
      final snapshot = computeSingleAccountBalance(
        accountId: 'cash-1',
        nature: AccountNature.asset,
        openingBalance: 100,
        entryPayloads: [
          {
            'debit_account_id': 'cash-1',
            'credit_account_id': virtualIncomeAccountId(
              ledgerScope: LedgerScope.accounting,
              category: 'Продажа',
            ),
            'amount': 1000.0,
          },
          {
            'debit_account_id': virtualExpenseAccountId(
              ledgerScope: LedgerScope.accounting,
              category: 'Топливо',
            ),
            'credit_account_id': 'cash-1',
            'amount': 300.0,
          },
          {
            'debit_account_id': 'cash-1',
            'credit_account_id': virtualIncomeAccountId(
              ledgerScope: LedgerScope.accounting,
              category: 'Возврат',
            ),
            'amount': 50.0,
          },
        ],
      );

      expect(snapshot.closingBalance, 850);
      expect(snapshot.debitTurnover, 1050);
      expect(snapshot.creditTurnover, 300);
    });

    test('retrospective opening balance keeps earlier postings in balance', () {
      final snapshot = computeSingleAccountBalance(
        accountId: 'bank-1',
        nature: AccountNature.asset,
        openingBalance: 519818,
        entryPayloads: [
          {
            'debit_account_id': 'bank-1',
            'credit_account_id': virtualIncomeAccountId(
              ledgerScope: LedgerScope.accounting,
              category: 'Доход',
            ),
            'amount': 2386727.0,
            'entry_date': DateTime(2026, 5, 25),
          },
          {
            'debit_account_id': virtualExpenseAccountId(
              ledgerScope: LedgerScope.accounting,
              category: 'Расход',
            ),
            'credit_account_id': 'bank-1',
            'amount': 1300000.0,
            'entry_date': DateTime(2026, 5, 25),
          },
        ],
      );

      expect(snapshot.closingBalance, 1606545);
      expect(snapshot.debitTurnover, 2386727);
      expect(snapshot.creditTurnover, 1300000);
    });

    test('opening balance date excludes earlier postings from account balance',
        () {
      final snapshot = computeSingleAccountBalance(
        accountId: 'bank-1',
        nature: AccountNature.asset,
        openingBalance: 519818,
        openingBalanceDate: DateTime(2026, 7, 24),
        entryPayloads: [
          {
            'debit_account_id': 'bank-1',
            'credit_account_id': virtualIncomeAccountId(
              ledgerScope: LedgerScope.accounting,
              category: 'Исторический доход',
            ),
            'amount': 1000000.0,
            'entry_date': DateTime(2026, 5, 25),
          },
          {
            'debit_account_id': 'bank-1',
            'credit_account_id': virtualIncomeAccountId(
              ledgerScope: LedgerScope.accounting,
              category: 'Текущий доход',
            ),
            'amount': 1000.0,
            'entry_date': DateTime(2026, 7, 24),
          },
        ],
      );

      expect(snapshot.debitTurnover, 1000);
      expect(snapshot.creditTurnover, 0);
      expect(snapshot.closingBalance, 520818);
    });

    test('detects entries before opening balance date by calendar day', () {
      expect(
        isEntryDateBeforeOpeningBalanceDate(
          entryDate: DateTime(2026, 7, 23, 23, 59),
          openingBalanceDate: DateTime(2026, 7, 24),
        ),
        isTrue,
      );
      expect(
        isEntryDateBeforeOpeningBalanceDate(
          entryDate: DateTime(2026, 7, 24, 0, 1),
          openingBalanceDate: DateTime(2026, 7, 24),
        ),
        isFalse,
      );
    });
  });
}
