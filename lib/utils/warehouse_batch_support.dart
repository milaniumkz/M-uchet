import 'package:cloud_firestore/cloud_firestore.dart';

import '/utils/inventory_batch_support.dart';
import '/utils/inventory_costing_method.dart';
import '/utils/ledger_scope.dart';

class WarehouseBatchMutationPlan {
  const WarehouseBatchMutationPlan({
    required this.batchWrites,
    required this.sourceQtyRemaining,
    required this.sourceValueRemaining,
    required this.mutatedBatchCount,
    required this.totalCost,
  });

  final List<WarehouseDocWrite> batchWrites;
  final double sourceQtyRemaining;
  final double sourceValueRemaining;
  final int mutatedBatchCount;
  final double totalCost;
}

class WarehouseDocWrite {
  const WarehouseDocWrite(
    this.reference,
    this.data, {
    this.merge = false,
  });

  final dynamic reference;
  final Map<String, dynamic> data;
  final bool merge;
}

WarehouseBatchMutationPlan buildWarehouseWriteoffPlan({
  required dynamic firestore,
  required String companyId,
  required String productId,
  required String productName,
  required String warehouseId,
  required String warehouseName,
  required LedgerScope ledgerScope,
  required List<InventoryBatchEntry> batches,
  required double qty,
  InventoryCostingMethod costingMethod = InventoryCostingMethod.fifo,
}) {
  final costing = consumeInventoryBatches(
    batches: batches,
    ledgerScope: ledgerScope,
    requestedQty: qty,
    costingMethod: costingMethod,
  );
  final writes = <WarehouseDocWrite>[];
  for (final batch in costing.updatedBatches) {
    writes.add(
      WarehouseDocWrite(
        firestore.collection('inventory_batches').doc(batch.id),
        <String, dynamic>{
          'qty_remaining': batch.qtyRemaining,
          'total_cost': batch.qtyRemaining * batch.unitCost,
          'status': batch.qtyRemaining <= 0 ? 'DEPLETED' : 'ACTIVE',
          'is_active': batch.qtyRemaining > 0,
          'updated_at': FieldValue.serverTimestamp(),
        },
        merge: true,
      ),
    );
  }

  return WarehouseBatchMutationPlan(
    batchWrites: writes,
    sourceQtyRemaining: costing.remainingQty,
    sourceValueRemaining: costing.remainingValue,
    mutatedBatchCount: costing.consumptions.length,
    totalCost: costing.totalCost,
  );
}

class WarehouseMoveMutationPlan {
  const WarehouseMoveMutationPlan({
    required this.batchWrites,
    required this.sourceQtyRemaining,
    required this.sourceValueRemaining,
    required this.movedQty,
    required this.movedValue,
  });

  final List<WarehouseDocWrite> batchWrites;
  final double sourceQtyRemaining;
  final double sourceValueRemaining;
  final double movedQty;
  final double movedValue;
}

WarehouseMoveMutationPlan buildWarehouseMovePlan({
  required dynamic firestore,
  required String companyId,
  required String sourceProductId,
  required String sourceProductName,
  required String sourceWarehouseId,
  required String sourceWarehouseName,
  required String targetProductId,
  required String targetWarehouseId,
  required String targetWarehouseName,
  required LedgerScope ledgerScope,
  required List<InventoryBatchEntry> sourceBatches,
  required double qty,
  InventoryCostingMethod costingMethod = InventoryCostingMethod.fifo,
}) {
  final costing = consumeInventoryBatches(
    batches: sourceBatches,
    ledgerScope: ledgerScope,
    requestedQty: qty,
    costingMethod: costingMethod,
  );
  final writes = <WarehouseDocWrite>[];
  for (final batch in costing.updatedBatches) {
    writes.add(
      WarehouseDocWrite(
        firestore.collection('inventory_batches').doc(batch.id),
        <String, dynamic>{
          'qty_remaining': batch.qtyRemaining,
          'total_cost': batch.qtyRemaining * batch.unitCost,
          'status': batch.qtyRemaining <= 0 ? 'DEPLETED' : 'ACTIVE',
          'is_active': batch.qtyRemaining > 0,
          'updated_at': FieldValue.serverTimestamp(),
        },
        merge: true,
      ),
    );
  }
  for (final consumption in costing.consumptions) {
    writes.add(
      WarehouseDocWrite(
        firestore.collection('inventory_batches').doc(),
        buildInventoryBatchPayload(
          companyId: companyId,
          productId: targetProductId,
          productName: sourceProductName,
          warehouseId: targetWarehouseId,
          warehouseName: targetWarehouseName,
          ledgerScope: ledgerScope,
          qtyInitial: consumption.qty,
          qtyRemaining: consumption.qty,
          unitCost: costing.unitCostApplied,
          totalCost: consumption.qty * costing.unitCostApplied,
          sourceDocType: 'warehouse_move',
          sourceDocId: sourceProductId,
        ),
      ),
    );
  }

  return WarehouseMoveMutationPlan(
    batchWrites: writes,
    sourceQtyRemaining: costing.remainingQty,
    sourceValueRemaining: costing.remainingValue,
    movedQty: qty,
    movedValue: costing.totalCost,
  );
}

List<InventoryBatchEntry> inventoryBatchesForProduct({
  required List<InventoryBatchEntry> batches,
  required String warehouseId,
  required LedgerScope ledgerScope,
}) {
  return batches
      .where((batch) =>
          batch.warehouseId == warehouseId && batch.ledgerScope == ledgerScope)
      .toList();
}
