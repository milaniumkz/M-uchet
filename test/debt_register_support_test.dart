import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/debt_aging_service.dart';
import 'package:uchet_s_d/utils/debt_register_support.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';

void main() {
  test('AR and AP payloads are created with proper type', () {
    final arPayload = buildDebtRecordPayload(
      idCompany: 'c1',
      type: DebtType.ar,
      counterpartyId: 'client-1',
      counterpartyName: 'Client',
      sourceDocumentId: 'sale-1',
      sourceType: 'sale',
      totalAmount: 500,
      remainingAmount: 500,
      ledgerScope: LedgerScope.management,
    );
    final apPayload = buildDebtRecordPayload(
      idCompany: 'c1',
      type: DebtType.ap,
      counterpartyId: 'vendor-1',
      counterpartyName: 'Vendor',
      sourceDocumentId: 'purchase-1',
      sourceType: 'purchase',
      totalAmount: 300,
      remainingAmount: 300,
      ledgerScope: LedgerScope.accounting,
    );

    expect(arPayload['type'], 'AR');
    expect(apPayload['type'], 'AP');
    expect(arPayload['source_type'], 'sale');
    expect(apPayload['source_type'], 'purchase');
  });

  test('AP debt payload and FIFO payment allocation work', () {
    final older = DebtRecordView.fromMap({
      'id': 'd1',
      'type': 'AP',
      'counterparty_name': 'Vendor',
      'source_document_id': 'o1',
      'source_type': 'obligation',
      'total_amount': 1000,
      'remaining_amount': 1000,
      'ledger_scope': 'management',
      'created_at': DateTime(2024, 1, 1),
      'idCompany': 'c1',
    });
    final newer = DebtRecordView.fromMap({
      'id': 'd2',
      'type': 'AP',
      'counterparty_name': 'Vendor',
      'source_document_id': 'o2',
      'source_type': 'obligation',
      'total_amount': 800,
      'remaining_amount': 800,
      'ledger_scope': 'management',
      'created_at': DateTime(2024, 2, 1),
      'idCompany': 'c1',
    });

    final result = applyDebtPaymentFifo(
      debts: [newer, older],
      paymentAmount: 1200,
    );

    expect(result.allocations.length, 2);
    expect(result.allocations.first.debtId, 'd1');
    expect(result.allocations.first.amount, 1000);
    expect(result.allocations.last.debtId, 'd2');
    expect(result.allocations.last.amount, 200);
    expect(result.updatedDebts.firstWhere((d) => d.id == 'd1').remainingAmount, 0);
    expect(result.updatedDebts.firstWhere((d) => d.id == 'd2').remainingAmount, 600);
    expect(result.unappliedAmount, 0);
  });

  test('aging summary splits debts into buckets', () {
    final asOf = DateTime(2024, 5, 1);
    final debts = [
      DebtRecordView.fromMap({
        'id': 'ar1',
        'type': 'AR',
        'remaining_amount': 100,
        'total_amount': 100,
        'ledger_scope': 'management',
        'created_at': DateTime(2024, 4, 20),
      }),
      DebtRecordView.fromMap({
        'id': 'ar2',
        'type': 'AR',
        'remaining_amount': 200,
        'total_amount': 200,
        'ledger_scope': 'management',
        'created_at': DateTime(2024, 3, 15),
      }),
      DebtRecordView.fromMap({
        'id': 'ar3',
        'type': 'AR',
        'remaining_amount': 300,
        'total_amount': 300,
        'ledger_scope': 'management',
        'created_at': DateTime(2024, 1, 1),
      }),
    ];

    final summary = DebtAgingService.compute(
      debts: debts,
      asOf: asOf,
      type: DebtType.ar,
    );

    expect(summary.bucket0To30, 100);
    expect(summary.bucket31To60, 200);
    expect(summary.bucket61To90, 0);
    expect(summary.bucket90Plus, 300);
  });

  test('credit limit overflow is detected', () {
    final debt = DebtRecordView.fromMap({
      'id': 'ar-limit',
      'type': 'AR',
      'remaining_amount': 1500,
      'total_amount': 1500,
      'credit_limit': 1000,
      'ledger_scope': LedgerScope.management.storageValue,
    });

    expect(debt.isCreditLimitExceeded, isTrue);
  });

  test('payment link payload is created', () {
    final payload = buildDebtPaymentLinkPayload(
      idCompany: 'c1',
      debtId: 'debt-1',
      paymentTransactionId: 'tx-1',
      amount: 250,
      ledgerScope: LedgerScope.accounting,
    );

    expect(payload['debt_id'], 'debt-1');
    expect(payload['payment_transaction_id'], 'tx-1');
    expect(payload['amount'], 250);
    expect(payload['ledger_scope'], LedgerScope.accounting.storageValue);
  });

  test('non-positive payment amount does not mutate debts', () {
    final debt = DebtRecordView.fromMap({
      'id': 'd1',
      'type': 'AP',
      'counterparty_name': 'Vendor',
      'source_document_id': 'o1',
      'source_type': 'obligation',
      'total_amount': 1000,
      'remaining_amount': 1000,
      'ledger_scope': 'management',
      'created_at': DateTime(2024, 1, 1),
      'idCompany': 'c1',
    });

    final result = applyDebtPaymentFifo(
      debts: [debt],
      paymentAmount: 0,
    );

    expect(result.allocations, isEmpty);
    expect(result.updatedDebts.single.remainingAmount, 1000);
    expect(result.unappliedAmount, 0);
  });
}
