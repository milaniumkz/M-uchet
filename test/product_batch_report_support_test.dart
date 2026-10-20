import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/product_batch_report_support.dart';

void main() {
  test('buildProductBatchRows returns active rows for product', () {
    final rows = buildProductBatchRows(
      product: {
        'id': 'p1',
        'inventory_costing_method': 'WEIGHTED_AVERAGE',
      },
      inventoryBatches: [
        {
          'id': 'b1',
          'product_id': 'p1',
          'warehouse_name': 'Склад А',
          'ledger_scope': 'ACCOUNTING',
          'qty_remaining': 3,
          'unit_cost': 100,
          'received_at': DateTime(2025, 1, 10),
        },
        {
          'id': 'b2',
          'product_id': 'p1',
          'warehouse_name': 'Склад B',
          'ledger_scope': 'MANAGEMENT',
          'qty_remaining': 2,
          'unit_cost': 90,
          'received_at': DateTime(2025, 1, 12),
        },
        {
          'id': 'b3',
          'product_id': 'p1',
          'warehouse_name': 'Склад C',
          'ledger_scope': 'ACCOUNTING',
          'qty_remaining': 0,
          'unit_cost': 80,
        },
        {
          'id': 'b4',
          'product_id': 'p2',
          'warehouse_name': 'Склад D',
          'ledger_scope': 'ACCOUNTING',
          'qty_remaining': 1,
          'unit_cost': 70,
        },
      ],
    );

    expect(rows, hasLength(2));
    expect(rows.first['batch_id'], 'b2');
    expect(rows.first['costing_method_label'], 'Средневзвешенная');
    expect(rows.first['ledger_scope_label'], 'Управленческий');
    expect(rows.last['total_value'], 300);
  });
}
