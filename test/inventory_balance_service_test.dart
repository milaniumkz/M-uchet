import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/inventory_balance_service.dart';
import 'package:uchet_s_d/utils/inventory_batch_support.dart';
import 'package:uchet_s_d/utils/inventory_costing_method.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';

InventoryBatchEntry _batch({
  required String id,
  required double qty,
  required double unitCost,
}) {
  return InventoryBatchEntry(
    id: id,
    companyId: 'c1',
    productId: 'p1',
    productName: 'Product 1',
    warehouseId: 'w1',
    warehouseName: 'Main',
    ledgerScope: LedgerScope.accounting,
    qtyInitial: qty,
    qtyRemaining: qty,
    unitCost: unitCost,
    raw: const <String, dynamic>{},
    createdAt: DateTime(2025, 1, 1),
  );
}

void main() {
  test('InventoryBalanceService returns qty and valuation from batches', () {
    const service = InventoryBalanceService();
    final batches = [
      _batch(id: 'b1', qty: 2, unitCost: 100),
      _batch(id: 'b2', qty: 3, unitCost: 200),
    ];

    expect(
      service.getAvailableQty(
        batches: batches,
        ledgerScope: LedgerScope.accounting,
      ),
      5,
    );
    expect(
      service.getInventoryValuation(
        batches: batches,
        ledgerScope: LedgerScope.accounting,
      ),
      800,
    );
  });

  test('InventoryBalanceService consumes by selected costing method', () {
    const service = InventoryBalanceService();
    final result = service.consumeInventory(
      batches: [
        _batch(id: 'b1', qty: 2, unitCost: 100),
        _batch(id: 'b2', qty: 3, unitCost: 200),
      ],
      ledgerScope: LedgerScope.accounting,
      requestedQty: 1,
      costingMethod: InventoryCostingMethod.weightedAverage,
    );

    expect(result.totalCost, 160);
    expect(result.remainingQty, 4);
  });
}
