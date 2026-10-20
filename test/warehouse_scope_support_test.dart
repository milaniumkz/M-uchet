import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/warehouse_scope_support.dart';

void main() {
  group('warehouse scope helpers', () {
    test('detects shop scoped roles', () {
      expect(isShopScopedRole({'role': 'shop_manager'}), isTrue);
      expect(isShopScopedRole({'role': 'Директор магазина'}), isTrue);
      expect(isShopScopedRole({'role': 'owner'}), isFalse);
    });

    test('resolves warehouse names from ids and explicit names', () {
      final names = resolveAllowedWarehouseNames(
        userData: {
          'warehouseIds': ['w2'],
          'warehouseNames': ['Склад 1'],
          'warehouseName': 'Склад 3',
        },
        warehouseDocs: const [
          {'id': 'w1', 'name': 'Склад 1'},
          {'id': 'w2', 'name': 'Склад 2'},
        ],
      );

      expect(names, {'Склад 1', 'Склад 2', 'Склад 3'});
    });

    test('filters rows for shop scoped users', () {
      final rows = [
        {'id': 'shop-1', 'name': 'Магазин 1'},
        {'shop_id': 'shop-2', 'name': 'Магазин 2'},
      ];

      expect(
        resolveAllowedShopIds({
          'role': 'Директор магазина',
          'shopId': 'shop-1',
          'allowedShopIds': ['shop-2'],
        }),
        {'shop-1', 'shop-2'},
      );
      expect(
        filterRowsByUserShopScope(
          userData: {'role': 'Директор магазина', 'shopId': 'shop-1'},
          rows: rows,
        ).map((row) => row['name']),
        ['Магазин 1'],
      );
      expect(
        filterRowsByUserShopScope(
          userData: {'role': 'Директор магазина'},
          rows: rows,
        ),
        isEmpty,
      );
      expect(
        filterRowsByUserShopScope(
          userData: {'role': 'owner'},
          rows: rows,
        ),
        rows,
      );
    });

    test('filters dependent rows by allowed sale ids', () {
      final rows = [
        {'id': 'cogs-1', 'sale_id': 'sale-1'},
        {'id': 'cogs-2', 'sale_id': 'sale-2'},
        {'id': 'cogs-3', 'sale_id': ''},
      ];

      expect(
        resolveSaleIdsFromRows([
          {'id': 'sale-1'},
          {'sale_id': 'sale-2'},
        ]),
        {'sale-1', 'sale-2'},
      );
      expect(
        filterRowsBySaleIds(rows: rows, saleIds: {'sale-2'}),
        [
          {'id': 'cogs-2', 'sale_id': 'sale-2'},
        ],
      );
    });

    test('keeps dependent rows by shop scope or sale id', () {
      final rows = [
        {'id': 'row-1', 'shop_id': 'shop-1'},
        {'id': 'row-2', 'sale_id': 'sale-2'},
        {'id': 'row-3', 'shop_id': 'shop-3', 'sale_id': 'sale-3'},
      ];

      expect(
        filterRowsByShopScopeOrSaleIds(
          userData: {'role': 'Директор магазина', 'shopId': 'shop-1'},
          rows: rows,
          saleIds: {'sale-2'},
        ).map((row) => row['id']),
        ['row-1', 'row-2'],
      );
    });

    test('keeps incassations linked to allowed cash register shifts', () {
      final registers = [
        {'id': 'shift-1', 'shop_id': 'shop-1'},
        {'id': 'shift-2', 'shop_id': 'shop-2'},
      ];
      final incassations = [
        {'id': 'inc-1', 'cash_register_shift_id': 'shift-1'},
        {'id': 'inc-2', 'cash_register_shift_id': 'shift-2'},
      ];

      expect(
        filterIncassationsByUserShopScope(
          userData: {'role': 'Директор магазина', 'shopId': 'shop-1'},
          incassations: incassations,
          cashRegisters: registers,
        ).map((row) => row['id']),
        ['inc-1'],
      );
    });
  });
}
