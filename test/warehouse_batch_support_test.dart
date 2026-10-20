import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/inventory_batch_support.dart';
import 'package:uchet_s_d/utils/inventory_costing_method.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';
import 'package:uchet_s_d/utils/warehouse_batch_support.dart';

class _FakeRef {
  const _FakeRef(this.path);

  final String path;
}

class _FakeCollection {
  const _FakeCollection(this.path);

  final String path;

  _FakeRef doc([String? id]) => _FakeRef('$path/${id ?? 'generated'}');
}

class _FakeFirestore {
  const _FakeFirestore();

  _FakeCollection collection(String path) => _FakeCollection(path);
}

InventoryBatchEntry _batch({
  required String id,
  required double qty,
  required double unitCost,
  required DateTime createdAt,
}) {
  return InventoryBatchEntry(
    id: id,
    companyId: 'c1',
    productId: 'p1',
    productName: 'Product',
    warehouseId: 'w1',
    warehouseName: 'Source',
    ledgerScope: LedgerScope.accounting,
    qtyInitial: qty,
    qtyRemaining: qty,
    unitCost: unitCost,
    createdAt: createdAt,
    raw: const <String, dynamic>{},
  );
}

void main() {
  test('warehouse writeoff uses FIFO cost and remaining cache', () {
    final firestore = const _FakeFirestore();
    final plan = buildWarehouseWriteoffPlan(
      firestore: firestore as dynamic,
      companyId: 'c1',
      productId: 'p1',
      productName: 'Product',
      warehouseId: 'w1',
      warehouseName: 'Source',
      ledgerScope: LedgerScope.accounting,
      batches: [
        _batch(
          id: 'b1',
          qty: 2,
          unitCost: 100,
          createdAt: DateTime(2025, 1, 1),
        ),
        _batch(
          id: 'b2',
          qty: 3,
          unitCost: 150,
          createdAt: DateTime(2025, 1, 2),
        ),
      ],
      qty: 4,
    );

    expect(plan.totalCost, 500);
    expect(plan.sourceQtyRemaining, 1);
    expect(plan.sourceValueRemaining, 150);
    expect(plan.mutatedBatchCount, 2);
  });

  test('warehouse move creates target batches from consumed FIFO layers', () {
    final firestore = const _FakeFirestore();
    final plan = buildWarehouseMovePlan(
      firestore: firestore as dynamic,
      companyId: 'c1',
      sourceProductId: 'p1',
      sourceProductName: 'Product',
      sourceWarehouseId: 'w1',
      sourceWarehouseName: 'Source',
      targetProductId: 'p2',
      targetWarehouseId: 'w2',
      targetWarehouseName: 'Target',
      ledgerScope: LedgerScope.accounting,
      sourceBatches: [
        _batch(
          id: 'b1',
          qty: 2,
          unitCost: 100,
          createdAt: DateTime(2025, 1, 1),
        ),
        _batch(
          id: 'b2',
          qty: 3,
          unitCost: 150,
          createdAt: DateTime(2025, 1, 2),
        ),
      ],
      qty: 3,
    );

    expect(plan.sourceQtyRemaining, 2);
    expect(plan.sourceValueRemaining, 300);
    expect(plan.movedQty, 3);
    expect(plan.movedValue, 350);
    expect(
      plan.batchWrites
          .where((write) => write.reference.path.contains('inventory_batches'))
          .length,
      greaterThanOrEqualTo(4),
    );
  });

  test('warehouse writeoff supports weighted average costing', () {
    final firestore = const _FakeFirestore();
    final plan = buildWarehouseWriteoffPlan(
      firestore: firestore as dynamic,
      companyId: 'c1',
      productId: 'p1',
      productName: 'Product',
      warehouseId: 'w1',
      warehouseName: 'Source',
      ledgerScope: LedgerScope.accounting,
      batches: [
        _batch(
          id: 'b1',
          qty: 2,
          unitCost: 100,
          createdAt: DateTime(2025, 1, 1),
        ),
        _batch(
          id: 'b2',
          qty: 3,
          unitCost: 200,
          createdAt: DateTime(2025, 1, 2),
        ),
      ],
      qty: 1,
      costingMethod: InventoryCostingMethod.weightedAverage,
    );

    expect(plan.totalCost, 160);
    expect(plan.sourceQtyRemaining, 4);
    expect(plan.sourceValueRemaining, 640);
  });
}
