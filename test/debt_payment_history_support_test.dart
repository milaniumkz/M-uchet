import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/debt_payment_history_support.dart';
import 'package:uchet_s_d/utils/debt_register_support.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';

void main() {
  test('buildDebtPaymentHistoryRows joins links with transactions and sorts desc', () {
    final rows = buildDebtPaymentHistoryRows(
      debtId: 'debt-1',
      paymentLinks: const [
        {
          'debt_id': 'debt-1',
          'payment_transaction_id': 'tx-1',
          'amount': 300,
          'created_at': '2024-05-02T00:00:00.000',
        },
        {
          'debt_id': 'debt-1',
          'payment_transaction_id': 'tx-2',
          'amount': 500,
          'created_at': '2024-05-03T00:00:00.000',
        },
        {
          'debt_id': 'debt-2',
          'payment_transaction_id': 'tx-9',
          'amount': 999,
        },
      ],
      transactions: const [
        {
          'id': 'tx-1',
          'schetTitle': 'Касса',
          'text': 'Погашение 1',
          'status': 'Проведена',
        },
        {
          'id': 'tx-2',
          'wallet_name': 'Банк',
          'text': 'Погашение 2',
          'status': 'Проведена',
        },
      ],
    );

    expect(rows, hasLength(2));
    expect(rows.first.paymentTransactionId, 'tx-2');
    expect(rows.first.accountTitle, 'Банк');
    expect(rows.first.amount, 500);
    expect(rows.last.paymentTransactionId, 'tx-1');
    expect(rows.last.accountTitle, 'Касса');
  });

  test('buildDebtPaymentTimelineRows joins debts links and filters by type', () {
    final rows = buildDebtPaymentTimelineRows(
      debts: [
        DebtRecordView.fromMap({
          'id': 'debt-1',
          'type': 'AR',
          'counterparty_name': 'Client A',
          'remaining_amount': 100,
          'total_amount': 100,
          'ledger_scope': LedgerScope.management.storageValue,
        }),
        DebtRecordView.fromMap({
          'id': 'debt-2',
          'type': 'AP',
          'counterparty_name': 'Supplier B',
          'remaining_amount': 100,
          'total_amount': 100,
          'ledger_scope': LedgerScope.management.storageValue,
        }),
      ],
      paymentLinks: const [
        {
          'debt_id': 'debt-1',
          'payment_transaction_id': 'tx-1',
          'amount': 50,
        },
        {
          'debt_id': 'debt-2',
          'payment_transaction_id': 'tx-2',
          'amount': 70,
        },
      ],
      transactions: const [
        {
          'id': 'tx-1',
          'schetTitle': 'Касса',
          'text': 'Погашение AR',
          'status': 'Проведена',
        },
        {
          'id': 'tx-2',
          'schetTitle': 'Банк',
          'text': 'Погашение AP',
          'status': 'Проведена',
        },
      ],
      type: DebtType.ar,
    );

    expect(rows, hasLength(1));
    expect(rows.single.debtId, 'debt-1');
    expect(rows.single.counterpartyName, 'Client A');
    expect(rows.single.accountTitle, 'Касса');
  });

  test('buildDebtPaymentTimelineExportRows includes columns and row values', () {
    final rows = buildDebtPaymentTimelineExportRows(
      title: 'Debt Timeline',
      rows: [
        DebtPaymentTimelineRow(
          debtId: 'debt-1',
          debtType: DebtType.ar,
          counterpartyName: 'Client A',
          paymentTransactionId: 'tx-1',
          amount: 50,
          createdAt: DateTime(2024, 5, 2),
          accountTitle: 'Касса',
          description: 'Погашение AR',
          status: 'Проведена',
          ledgerScope: LedgerScope.management,
        ),
      ],
    );

    expect(rows.first, ['Debt Timeline']);
    expect(rows.any((row) => row.contains('Контрагент')), isTrue);
    expect(rows.any((row) => row.contains('Client A')), isTrue);
  });
}
