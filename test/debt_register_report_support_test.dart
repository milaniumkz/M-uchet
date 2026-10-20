import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/debt_register_report_support.dart';
import 'package:uchet_s_d/utils/debt_register_support.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';

void main() {
  test('buildDebtRegisterRows filters sorts and preserves credit limit flags', () {
    final rows = buildDebtRegisterRows(
      debts: [
        DebtRecordView.fromMap({
          'id': 'ap-1',
          'type': 'AP',
          'counterparty_name': 'Supplier B',
          'source_type': 'purchase',
          'source_document_id': 'p-1',
          'total_amount': 500,
          'remaining_amount': 500,
          'credit_limit': 0,
          'ledger_scope': LedgerScope.accounting.storageValue,
          'created_at': DateTime(2024, 2, 1),
        }),
        DebtRecordView.fromMap({
          'id': 'ar-1',
          'type': 'AR',
          'counterparty_name': 'Client A',
          'source_type': 'sale',
          'source_document_id': 's-1',
          'total_amount': 1000,
          'remaining_amount': 800,
          'credit_limit': 300,
          'ledger_scope': LedgerScope.accounting.storageValue,
          'created_at': DateTime(2024, 1, 1),
        }),
        DebtRecordView.fromMap({
          'id': 'ar-closed',
          'type': 'AR',
          'counterparty_name': 'Client Z',
          'source_type': 'sale',
          'source_document_id': 's-9',
          'total_amount': 100,
          'remaining_amount': 0,
          'credit_limit': 0,
          'ledger_scope': LedgerScope.accounting.storageValue,
          'created_at': DateTime(2024, 3, 1),
        }),
      ],
      asOf: DateTime(2024, 5, 1),
      ledgerScope: LedgerScope.accounting,
    );

    expect(rows, hasLength(2));
    expect(rows.first.id, 'ar-1');
    expect(rows.first.isCreditLimitExceeded, isTrue);
    expect(rows.last.id, 'ap-1');
  });

  test('computeDebtRegisterSummary aggregates ar ap and aging', () {
    final summary = computeDebtRegisterSummary(
      debts: [
        DebtRecordView.fromMap({
          'id': 'ar-1',
          'type': 'AR',
          'counterparty_name': 'Client A',
          'source_type': 'sale',
          'source_document_id': 's-1',
          'total_amount': 1000,
          'remaining_amount': 800,
          'credit_limit': 300,
          'ledger_scope': LedgerScope.management.storageValue,
          'created_at': DateTime(2024, 1, 1),
          'due_date': DateTime(2024, 2, 1),
        }),
        DebtRecordView.fromMap({
          'id': 'ap-1',
          'type': 'AP',
          'counterparty_name': 'Supplier B',
          'source_type': 'purchase',
          'source_document_id': 'p-1',
          'total_amount': 500,
          'remaining_amount': 400,
          'credit_limit': 0,
          'ledger_scope': LedgerScope.management.storageValue,
          'created_at': DateTime(2024, 4, 1),
        }),
      ],
      asOf: DateTime(2024, 5, 1),
      ledgerScope: LedgerScope.management,
    );

    expect(summary.arTotal, 800);
    expect(summary.apTotal, 400);
    expect(summary.openCount, 2);
    expect(summary.overdueCount, 1);
    expect(summary.limitExceededCount, 1);
    expect(summary.arAging.bucket61To90, 800);
    expect(summary.apAging.bucket0To30, 400);
  });

  test('buildDebtRegisterExportRows includes summary and row details', () {
    final summary = DebtRegisterSummary(
      arTotal: 800,
      apTotal: 400,
      openCount: 2,
      overdueCount: 1,
      limitExceededCount: 1,
      arAging: const DebtAgingSummary(
        bucket0To30: 0,
        bucket31To60: 0,
        bucket61To90: 800,
        bucket90Plus: 0,
      ),
      apAging: const DebtAgingSummary(
        bucket0To30: 400,
        bucket31To60: 0,
        bucket61To90: 0,
        bucket90Plus: 0,
      ),
    );
    final rows = [
      DebtRegisterRow(
        id: 'ar-1',
        type: DebtType.ar,
        counterpartyName: 'Client A',
        sourceType: 'sale',
        sourceDocumentId: 's-1',
        totalAmount: 1000,
        remainingAmount: 800,
        ledgerScope: LedgerScope.management,
        status: DebtStatus.partial,
        createdAt: DateTime(2024, 1, 1),
        dueDate: DateTime(2024, 2, 1),
        creditLimit: 300,
        isCreditLimitExceeded: true,
        agingDays: 90,
      ),
    ];

    final exportRows = buildDebtRegisterExportRows(
      title: 'Debt Register',
      summary: summary,
      rows: rows,
    );

    expect(exportRows.first, ['Debt Register']);
    expect(exportRows.any((row) => row.contains('AR')), isTrue);
    expect(exportRows.any((row) => row.contains('Client A')), isTrue);
  });
}
