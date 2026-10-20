import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/inventory_batch_metrics_support.dart';

void main() {
  test('product valuation is rebuilt from inventory batches', () {
    final result = enrichProductsWithBatchValuation(
      products: [
        {
          'id': 'p1',
          'purchase_price': 999,
          'stock': 1,
          'stock_value': 999,
        }
      ],
      inventoryBatches: [
        {
          'product_id': 'p1',
          'warehouse_id': 'w1',
          'qty_remaining': 2,
          'unit_cost': 100,
        },
        {
          'product_id': 'p1',
          'warehouse_id': 'w2',
          'qty_remaining': 3,
          'unit_cost': 200,
        },
      ],
    );

    final item = (result['items'] as List).cast<Map<String, dynamic>>().first;
    expect(item['stock'], 5.0);
    expect(item['stock_value'], 800.0);
    expect(item['purchase_price'], 160.0);
  });

  test('warehouse valuation uses product plus warehouse key', () {
    final result = enrichWarehouseItemsWithBatchValuation(
      items: [
        {
          'id': 'p1',
          'warehouse': 'w1',
          'warehouse_id': 'w1',
          'stock': 99,
          'stock_value': 9999,
        },
        {
          'id': 'p1',
          'warehouse': 'w2',
          'warehouse_id': 'w2',
          'stock': 99,
          'stock_value': 9999,
        },
      ],
      inventoryBatches: [
        {
          'product_id': 'p1',
          'warehouse_id': 'w1',
          'qty_remaining': 2,
          'unit_cost': 100,
        },
        {
          'product_id': 'p1',
          'warehouse_id': 'w2',
          'qty_remaining': 3,
          'unit_cost': 200,
        },
      ],
    );

    final items = (result['items'] as List).cast<Map<String, dynamic>>();
    final w1 = items.firstWhere((item) => item['warehouse_id'] == 'w1');
    final w2 = items.firstWhere((item) => item['warehouse_id'] == 'w2');
    expect(w1['stock'], 2.0);
    expect(w1['stock_value'], 200.0);
    expect(w2['stock'], 3.0);
    expect(w2['stock_value'], 600.0);
  });
}
