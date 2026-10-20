import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/cogs_integrity_support.dart';

void main() {
  test('detects missing cogs, fifo batch gap and ledger mismatch', () {
    final summary = computeCogsIntegritySummary(
      salesItems: const [
        {
          'id': 'si-1',
          'sale_item_id': 'si-1',
          'sale_id': 'sale-1',
          'product_id': 'p1',
          'item_kind': 'product',
          'costing_method': 'FIFO',
          'ledger_scope': 'ACCOUNTING',
        },
        {
          'id': 'si-2',
          'sale_item_id': 'si-2',
          'sale_id': 'sale-2',
          'product_id': 'p2',
          'item_kind': 'product',
          'costing_method': 'FIFO',
          'ledger_scope': 'ACCOUNTING',
        },
        {
          'id': 'si-3',
          'sale_item_id': 'si-3',
          'sale_id': 'sale-3',
          'product_id': 'p3',
          'item_kind': 'service',
          'ledger_scope': 'ACCOUNTING',
        },
      ],
      cogsEntries: const [
        {
          'sale_item_id': 'si-1',
          'sale_id': 'sale-1',
          'product_id': 'p1',
          'ledger_scope': 'MANAGEMENT',
          'total_cost': 100,
        },
        {
          'sale_item_id': 'si-2',
          'sale_id': 'sale-2',
          'product_id': 'p2',
          'ledger_scope': 'ACCOUNTING',
          'total_cost': 120,
        },
      ],
      legacyCogsItems: const [],
      batchConsumptions: const [
        {
          'sale_item_id': 'si-1',
        },
      ],
    );

    expect(summary.salesItemsChecked, 3);
    expect(summary.missingCogsCount, 1);
    expect(summary.fifoMissingBatchCount, 1);
    expect(summary.ledgerMismatchCount, 1);
    expect(summary.totalIssues, 3);
  });

  test('builds export rows for cogs integrity summary', () {
    final rows = buildCogsIntegrityExportRows(
      summary: const CogsIntegritySummary(
        salesItemsChecked: 10,
        missingCogsCount: 2,
        fifoMissingBatchCount: 1,
        ledgerMismatchCount: 3,
      ),
    );

    expect(rows.first, ['COGS Audit']);
    expect(rows.last, ['Всего проблем', '6']);
  });
}
