import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/warehouse_inventory_support.dart';

void main() {
  group('buildWarehouseInventorySummary', () {
    test('groups warehouse rows and bucket stats consistently', () {
      final summary = buildWarehouseInventorySummary(
        warehouseDocs: [
          {
            'name': 'Официальные товары',
            'isVirtual': true,
          },
          {
            'name': 'Неофициальные товары',
            'isVirtual': true,
          },
          {
            'name': 'Склад 1',
            'parentWarehouse': 'Официальные товары',
          },
          {
            'name': 'Склад 2',
            'parentWarehouse': 'Неофициальные товары',
          },
        ],
        items: [
          {
            'warehouse': 'Склад 1',
            'stock': 5,
            'stock_value': 1000,
            'inventory_costing_method': 'FIFO',
          },
          {
            'warehouse': 'Склад 2',
            'stock': 2,
            'stock_value': 300,
            'inventory_costing_method': 'WEIGHTED_AVERAGE',
          },
        ],
        moves: [
          {
            'from_warehouse': 'Склад 1',
            'to_warehouse': 'Склад 2',
            'qty': 1,
            'created_at': DateTime(2025, 1, 10),
          },
        ],
        virtualWarehouses: const [
          'Официальные товары',
          'Неофициальные товары',
        ],
      );

      final rows = List<Map<String, dynamic>>.from(summary['rows'] as List);
      final official = List<Map<String, dynamic>>.from(
        summary['official'] as List,
      );
      final unofficial = List<Map<String, dynamic>>.from(
        summary['unofficial'] as List,
      );

      expect(summary['totalWarehouses'], 2);
      expect(summary['totalPositions'], 2);
      expect(summary['totalValue'], 1300.0);

      expect(rows.first['name'], 'Неофициальные товары');
      expect(rows.any((row) => row['name'] == 'Склад 1'), isTrue);
      expect(rows.any((row) => row['name'] == 'Склад 2'), isTrue);

      expect(official.single['name'], 'Склад 1');
      expect(official.single['outgoing'], 1.0);
      expect(official.single['costing_methods'], ['FIFO']);
      expect(unofficial.single['name'], 'Склад 2');
      expect(unofficial.single['incoming'], 1.0);
      expect(unofficial.single['costing_methods'], ['Средневзвешенная']);
    });
  });

  group('warehouseMovementKind', () {
    test('infers movement kinds from explicit or legacy fields', () {
      expect(warehouseMovementKind({'movement_kind': 'return'}), 'return');
      expect(
        warehouseMovementKind({'from_warehouse': 'Возврат поставщику'}),
        'return',
      );
      expect(
        warehouseMovementKind({'to_warehouse': 'Списан товар'}),
        'writeoff',
      );
      expect(
        warehouseMovementKind(
            {'from_warehouse': 'Склад 1', 'to_warehouse': 'Склад 2'}),
        'move',
      );
    });
  });
}
