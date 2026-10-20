import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/warehouse_batch_report_support.dart';

void main() {
  test('buildWarehouseBatchReport returns active rows and summary', () {
    final report = buildWarehouseBatchReport(
      inventoryBatches: [
        {
          'id': 'b1',
          'product_id': 'p1',
          'product_name': 'Товар 1',
          'warehouse_name': 'Склад А',
          'ledger_scope': 'ACCOUNTING',
          'qty_remaining': 3,
          'unit_cost': 100,
          'received_at': DateTime(2025, 1, 10),
        },
        {
          'id': 'b2',
          'product_id': 'p2',
          'warehouse_name': 'Склад B',
          'ledger_scope': 'MANAGEMENT',
          'qty_remaining': 2,
          'unit_cost': 50,
          'total_cost': 100,
          'received_at': DateTime(2025, 1, 12),
          'costing_method': 'WEIGHTED_AVERAGE',
        },
        {
          'id': 'b3',
          'product_id': 'p3',
          'warehouse_name': 'Склад C',
          'ledger_scope': 'ACCOUNTING',
          'qty_remaining': 0,
          'unit_cost': 30,
        },
        {
          'id': 'b4',
          'product_id': 'p4',
          'warehouse_name': 'Склад D',
          'ledger_scope': 'ACCOUNTING',
          'qty_remaining': 5,
          'unit_cost': 10,
          'is_active': false,
        },
      ],
      products: [
        {'id': 'p1', 'name': 'Товар 1', 'inventory_costing_method': 'FIFO'},
        {
          'id': 'p2',
          'name': 'Товар 2',
          'inventory_costing_method': 'WEIGHTED_AVERAGE',
        },
      ],
    );

    expect(report['total_batches'], 2);
    expect(report['total_qty'], 5);
    expect(report['total_value'], 400);

    final methodCounts = Map<String, int>.from(
      report['method_counts'] as Map? ?? const {},
    );
    expect(methodCounts['FIFO'], 1);
    expect(methodCounts['Средневзвешенная'], 1);

    final rows = List<Map<String, dynamic>>.from(report['rows'] as List);
    expect(rows.first['batch_id'], 'b2');
    expect(rows.first['product_name'], 'Товар 2');
    expect(rows.first['ledger_scope_label'], 'Управленческий');
    expect(rows.first['costing_method_label'], 'Средневзвешенная');
  });
}
