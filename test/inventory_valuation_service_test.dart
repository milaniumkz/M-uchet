import 'package:flutter_test/flutter_test.dart';

import 'package:uchet_s_d/utils/inventory_batch_support.dart';
import 'package:uchet_s_d/utils/inventory_valuation_service.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';
import 'package:uchet_s_d/utils/order_lifecycle_support.dart';

void main() {
  const service = InventoryValuationService();

  test('warehouse type prefers explicit field over warehouse name', () {
    final type = warehouseTypeFromData({
      'warehouse_type': 'UNOFFICIAL',
      'name': 'Официальные товары',
    });

    expect(type, WarehouseType.unofficial);
  });

  test('inventory valuation uses batch costs and reservation-aware qty', () {
    final batches = <InventoryBatchEntry>[
      InventoryBatchEntry.fromMap({
        'id': 'b1',
        'idCompany': 'c1',
        'product_id': 'p1',
        'product_name': 'Товар',
        'warehouse_id': 'w1',
        'warehouse_name': 'Склад 1',
        'ledger_scope': 'ACCOUNTING',
        'qty_initial': 10,
        'qty_remaining': 6,
        'unit_cost': 100,
        'status': 'ACTIVE',
      }),
      InventoryBatchEntry.fromMap({
        'id': 'b2',
        'idCompany': 'c1',
        'product_id': 'p1',
        'product_name': 'Товар',
        'warehouse_id': 'w1',
        'warehouse_name': 'Склад 1',
        'ledger_scope': 'ACCOUNTING',
        'qty_initial': 4,
        'qty_remaining': 4,
        'unit_cost': 120,
        'status': 'ACTIVE',
      }),
    ];
    final reservations = <InventoryReservationEntry>[
      InventoryReservationEntry.fromMap({
        'id': 'r1',
        'order_id': 'o1',
        'order_item_id': 'oi1',
        'product_id': 'p1',
        'warehouse_id': 'w1',
        'ledger_scope': 'ACCOUNTING',
        'quantity_reserved': 3,
        'quantity_released': 1,
        'quantity_consumed': 0,
        'status': 'RESERVED',
      }),
    ];

    expect(
      service.getStockQty(
        batches: batches,
        ledgerScope: LedgerScope.accounting,
        productId: 'p1',
        warehouseId: 'w1',
      ),
      10,
    );
    expect(
      service.getReservedQty(
        reservations: reservations,
        ledgerScope: LedgerScope.accounting,
        productId: 'p1',
        warehouseId: 'w1',
      ),
      2,
    );
    expect(
      service.getAvailableQty(
        batches: batches,
        reservations: reservations,
        ledgerScope: LedgerScope.accounting,
        productId: 'p1',
        warehouseId: 'w1',
      ),
      8,
    );
    expect(
      service.getStockValue(
        batches: batches,
        ledgerScope: LedgerScope.accounting,
        productId: 'p1',
        warehouseId: 'w1',
      ),
      1080,
    );
  });
}
