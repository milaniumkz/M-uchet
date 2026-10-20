import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/inventory_batch_support.dart';
import 'package:uchet_s_d/utils/inventory_costing_method.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';

InventoryBatchEntry _batch({
  required String id,
  required double qtyInitial,
  required double qtyRemaining,
  required double unitCost,
  required DateTime createdAt,
  LedgerScope ledgerScope = LedgerScope.accounting,
}) {
  return InventoryBatchEntry(
    id: id,
    companyId: 'c1',
    productId: 'p1',
    productName: 'Product 1',
    warehouseId: 'w1',
    warehouseName: 'Main',
    ledgerScope: ledgerScope,
    qtyInitial: qtyInitial,
    qtyRemaining: qtyRemaining,
    unitCost: unitCost,
    createdAt: createdAt,
    raw: const <String, dynamic>{},
  );
}

void main() {
  test('FIFO списание идёт по самым ранним партиям', () {
    final result = consumeInventoryBatchesFifo(
      batches: [
        _batch(
          id: 'b2',
          qtyInitial: 5,
          qtyRemaining: 5,
          unitCost: 200,
          createdAt: DateTime(2025, 2, 1),
        ),
        _batch(
          id: 'b1',
          qtyInitial: 3,
          qtyRemaining: 3,
          unitCost: 100,
          createdAt: DateTime(2025, 1, 1),
        ),
      ],
      ledgerScope: LedgerScope.accounting,
      requestedQty: 4,
    );

    expect(result.consumptions.length, 2);
    expect(result.consumptions[0].batchId, 'b1');
    expect(result.consumptions[0].qty, 3);
    expect(result.consumptions[1].batchId, 'b2');
    expect(result.consumptions[1].qty, 1);
  });

  test('расчёт себестоимости суммирует стоимость по партиям', () {
    final result = consumeInventoryBatchesFifo(
      batches: [
        _batch(
          id: 'b1',
          qtyInitial: 2,
          qtyRemaining: 2,
          unitCost: 100,
          createdAt: DateTime(2025, 1, 1),
        ),
        _batch(
          id: 'b2',
          qtyInitial: 3,
          qtyRemaining: 3,
          unitCost: 150,
          createdAt: DateTime(2025, 1, 2),
        ),
      ],
      ledgerScope: LedgerScope.accounting,
      requestedQty: 4,
    );

    expect(result.totalCost, 500);
    expect(result.remainingQty, 1);
    expect(result.remainingValue, 150);
  });

  test('недостаточный остаток выбрасывает InventoryBatchException', () {
    expect(
      () => consumeInventoryBatchesFifo(
        batches: [
          _batch(
            id: 'b1',
            qtyInitial: 2,
            qtyRemaining: 2,
            unitCost: 100,
            createdAt: DateTime(2025, 1, 1),
          ),
        ],
        ledgerScope: LedgerScope.accounting,
        requestedQty: 3,
      ),
      throwsA(isA<InventoryBatchException>()),
    );
  });

  test('частичное списание партии уменьшает только qtyRemaining', () {
    final result = consumeInventoryBatchesFifo(
      batches: [
        _batch(
          id: 'b1',
          qtyInitial: 10,
          qtyRemaining: 10,
          unitCost: 120,
          createdAt: DateTime(2025, 1, 1),
        ),
      ],
      ledgerScope: LedgerScope.accounting,
      requestedQty: 4,
    );

    expect(result.updatedBatches.single.qtyInitial, 10);
    expect(result.updatedBatches.single.qtyRemaining, 6);
    expect(result.totalCost, 480);
  });

  test('запрещено смешивать партии разных ledger_scope', () {
    expect(
      () => consumeInventoryBatchesFifo(
        batches: [
          _batch(
            id: 'b1',
            qtyInitial: 2,
            qtyRemaining: 2,
            unitCost: 100,
            createdAt: DateTime(2025, 1, 1),
            ledgerScope: LedgerScope.management,
          ),
        ],
        ledgerScope: LedgerScope.accounting,
        requestedQty: 1,
      ),
      throwsA(isA<InventoryBatchException>()),
    );
  });

  test('weighted average рассчитывает среднюю себестоимость по остаткам', () {
    final result = consumeInventoryBatchesWeightedAverage(
      batches: [
        _batch(
          id: 'b1',
          qtyInitial: 2,
          qtyRemaining: 2,
          unitCost: 100,
          createdAt: DateTime(2025, 1, 1),
        ),
        _batch(
          id: 'b2',
          qtyInitial: 3,
          qtyRemaining: 3,
          unitCost: 200,
          createdAt: DateTime(2025, 1, 2),
        ),
      ],
      ledgerScope: LedgerScope.accounting,
      requestedQty: 2,
    );

    expect(result.costingMethod, InventoryCostingMethod.weightedAverage);
    expect(result.unitCostApplied, 160);
    expect(result.totalCost, 320);
    expect(result.remainingQty, 3);
    expect(result.remainingValue, 480);
    expect(result.consumptions.single.batchId, isEmpty);
  });

  test('universal consumeInventoryBatches switches by configured method', () {
    final fifo = consumeInventoryBatches(
      batches: [
        _batch(
          id: 'b1',
          qtyInitial: 1,
          qtyRemaining: 1,
          unitCost: 100,
          createdAt: DateTime(2025, 1, 1),
        ),
        _batch(
          id: 'b2',
          qtyInitial: 1,
          qtyRemaining: 1,
          unitCost: 200,
          createdAt: DateTime(2025, 1, 2),
        ),
      ],
      ledgerScope: LedgerScope.accounting,
      requestedQty: 1,
      costingMethod: InventoryCostingMethod.fifo,
    );
    final weighted = consumeInventoryBatches(
      batches: [
        _batch(
          id: 'b1',
          qtyInitial: 1,
          qtyRemaining: 1,
          unitCost: 100,
          createdAt: DateTime(2025, 1, 1),
        ),
        _batch(
          id: 'b2',
          qtyInitial: 1,
          qtyRemaining: 1,
          unitCost: 200,
          createdAt: DateTime(2025, 1, 2),
        ),
      ],
      ledgerScope: LedgerScope.accounting,
      requestedQty: 1,
      costingMethod: InventoryCostingMethod.weightedAverage,
    );

    expect(fifo.totalCost, 100);
    expect(weighted.totalCost, 150);
  });

  test('legacy backfill payload creates cache-backed inventory batch', () {
    final payload = buildLegacyInventoryBackfillBatchPayload(
      companyId: 'c1',
      productId: 'p1',
      productName: 'Product 1',
      warehouseId: 'w1',
      warehouseName: 'Main',
      ledgerScope: LedgerScope.accounting,
      qtyRemaining: 6,
      unitCost: 120,
    );

    expect(payload['product_id'], 'p1');
    expect(payload['qty_initial'], 6);
    expect(payload['qty_remaining'], 6);
    expect(payload['unit_cost'], 120);
    expect(payload['is_legacy_cache'], isTrue);
    expect(payload['ledger_scope'], LedgerScope.accounting.storageValue);
  });

  test('prepareInventoryBatchesForSale creates synthetic batch only when no batches exist', () {
    final result = prepareInventoryBatchesForSale(
      companyId: 'c1',
      productId: 'p1',
      productName: 'Product 1',
      warehouseId: 'w1',
      warehouseName: 'Main',
      ledgerScope: LedgerScope.accounting,
      existingBatches: const [],
      stockQty: 6,
      unitCost: 120,
      syntheticBatchId: 'legacy-batch',
    );

    expect(result.batches.single.id, 'legacy-batch');
    expect(result.batches.single.qtyRemaining, 6);
    expect(result.syntheticBatchPayload?['is_legacy_cache'], isTrue);
  });

  test('prepareInventoryBatchesForSale rejects partial batch mismatch against cache stock', () {
    expect(
      () => prepareInventoryBatchesForSale(
        companyId: 'c1',
        productId: 'p1',
        productName: 'Product 1',
        warehouseId: 'w1',
        warehouseName: 'Main',
        ledgerScope: LedgerScope.accounting,
        existingBatches: [
          _batch(
            id: 'b1',
            qtyInitial: 2,
            qtyRemaining: 2,
            unitCost: 100,
            createdAt: DateTime(2025, 1, 1),
          ),
        ],
        stockQty: 5,
        unitCost: 100,
        syntheticBatchId: 'legacy-batch',
      ),
      throwsA(isA<InventoryBatchException>()),
    );
  });

  test('sale item cogs payload stores costing method and applied basis', () {
    final payload = buildSaleItemCogsPayload(
      companyId: 'c1',
      saleId: 's1',
      saleItemId: 'si1',
      productId: 'p1',
      productName: 'Product 1',
      warehouseId: 'w1',
      warehouseName: 'Main',
      ledgerScope: LedgerScope.accounting,
      consumption: const InventoryBatchConsumption(
        batchId: '',
        qty: 2,
        unitCost: 160,
        totalCost: 320,
        costingMethod: InventoryCostingMethod.weightedAverage,
      ),
      costingMethod: InventoryCostingMethod.weightedAverage,
      unitCostApplied: 160,
    );

    expect(payload['costing_method'], 'WEIGHTED_AVERAGE');
    expect(payload['unit_cost_applied'], 160);
    expect(payload['batch_id'], isNull);
  });

  test('batch consumption payload stores explicit batch-sale linkage', () {
    final payload = buildBatchConsumptionPayload(
      companyId: 'c1',
      saleId: 'sale-1',
      saleItemId: 'item-1',
      ledgerScope: LedgerScope.accounting,
      consumption: const InventoryBatchConsumption(
        batchId: 'batch-1',
        qty: 2,
        unitCost: 150,
        totalCost: 300,
        costingMethod: InventoryCostingMethod.fifo,
      ),
    );

    expect(payload['sale_id'], 'sale-1');
    expect(payload['sale_item_id'], 'item-1');
    expect(payload['batch_id'], 'batch-1');
    expect(payload['source_batch_id'], 'batch-1');
    expect(payload['quantity'], 2.0);
    expect(payload['unit_cost'], 150.0);
    expect(payload['total_cost'], 300.0);
    expect(payload['ledger_scope'], 'ACCOUNTING');
  });

  test('cogs entry payload stores register data with batch reference', () {
    final payload = buildCogsEntryPayload(
      companyId: 'c1',
      saleId: 'sale-1',
      saleItemId: 'item-1',
      productId: 'p1',
      productName: 'Product 1',
      warehouseId: 'w1',
      warehouseName: 'Main',
      ledgerScope: LedgerScope.accounting,
      consumption: const InventoryBatchConsumption(
        batchId: 'batch-1',
        qty: 2,
        unitCost: 140,
        totalCost: 280,
        costingMethod: InventoryCostingMethod.fifo,
      ),
      costingMethod: InventoryCostingMethod.fifo,
      unitCostApplied: 140,
    );

    expect(payload['sale_id'], 'sale-1');
    expect(payload['sale_item_id'], 'item-1');
    expect(payload['product_id'], 'p1');
    expect(payload['warehouse_id'], 'w1');
    expect(payload['batch_id'], 'batch-1');
    expect(payload['source_batch_id'], 'batch-1');
    expect(payload['quantity'], 2.0);
    expect(payload['unit_cost'], 140.0);
    expect(payload['total_cost'], 280.0);
    expect(payload['costing_method'], 'FIFO');
    expect(payload['ledger_scope'], 'ACCOUNTING');
  });
}
