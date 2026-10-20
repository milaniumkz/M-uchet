import '/utils/inventory_batch_support.dart';
import '/utils/inventory_costing_method.dart';
import '/utils/inventory_valuation_service.dart';
import '/utils/ledger_scope.dart';
import '/utils/order_lifecycle_support.dart';

class InventoryBalanceService {
  const InventoryBalanceService();

  static const InventoryValuationService valuationService =
      InventoryValuationService();

  double getAvailableQty({
    required List<InventoryBatchEntry> batches,
    required LedgerScope ledgerScope,
    String? productId,
    String? warehouseId,
    List<InventoryReservationEntry> reservations = const [],
  }) {
    final physical = productId == null || warehouseId == null
        ? calculateInventoryValuation(
            batches: batches,
            ledgerScope: ledgerScope,
          ).availableQty
        : getStockQty(
            batches: batches,
            ledgerScope: ledgerScope,
            productId: productId,
            warehouseId: warehouseId,
          );
    if (productId == null || warehouseId == null) {
      return physical;
    }
    return computeAvailableQty(
      physicalQty: physical,
      reservations: reservations,
      productId: productId,
      warehouseId: warehouseId,
      ledgerScope: ledgerScope,
    );
  }

  double getPhysicalQty({
    required List<InventoryBatchEntry> batches,
    required LedgerScope ledgerScope,
  }) {
    return calculateInventoryValuation(
      batches: batches,
      ledgerScope: ledgerScope,
    ).availableQty;
  }

  double getReservedQty({
    required List<InventoryReservationEntry> reservations,
    required String productId,
    required String warehouseId,
    required LedgerScope ledgerScope,
  }) {
    return computeReservedQty(
      reservations: reservations,
      productId: productId,
      warehouseId: warehouseId,
      ledgerScope: ledgerScope,
    );
  }

  double getInventoryValuation({
    required List<InventoryBatchEntry> batches,
    required LedgerScope ledgerScope,
  }) {
    return valuationService.getTotalInventoryValue(
      batches: batches,
      ledgerScope: ledgerScope,
    );
  }

  double getStockValue({
    required List<InventoryBatchEntry> batches,
    required LedgerScope ledgerScope,
    String? productId,
    String? warehouseId,
  }) {
    return valuationService.getStockValue(
      batches: batches,
      ledgerScope: ledgerScope,
      productId: productId,
      warehouseId: warehouseId,
    );
  }

  double getStockQty({
    required List<InventoryBatchEntry> batches,
    required LedgerScope ledgerScope,
    String? productId,
    String? warehouseId,
  }) {
    return valuationService.getStockQty(
      batches: batches,
      ledgerScope: ledgerScope,
      productId: productId,
      warehouseId: warehouseId,
    );
  }

  InventoryBatchCostingResult consumeInventory({
    required List<InventoryBatchEntry> batches,
    required LedgerScope ledgerScope,
    required double requestedQty,
    required InventoryCostingMethod costingMethod,
  }) {
    return consumeInventoryBatches(
      batches: batches,
      ledgerScope: ledgerScope,
      requestedQty: requestedQty,
      costingMethod: costingMethod,
    );
  }

  InventoryBatchEntry receiveInventory({
    required String id,
    required String companyId,
    required String productId,
    required String productName,
    required String warehouseId,
    required String warehouseName,
    required LedgerScope ledgerScope,
    required double qty,
    required double unitCost,
    required String sourceDocumentId,
    required String sourceType,
    DateTime? receivedAt,
  }) {
    return InventoryBatchEntry(
      id: id,
      companyId: companyId,
      productId: productId,
      productName: productName,
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      ledgerScope: ledgerScope,
      qtyInitial: qty,
      qtyRemaining: qty,
      unitCost: unitCost,
      totalCost: qty * unitCost,
      createdAt: receivedAt,
      receivedAt: receivedAt,
      sourceDocumentId: sourceDocumentId,
      sourceType: sourceType,
      isActive: true,
      status: 'ACTIVE',
      raw: const <String, dynamic>{},
    );
  }
}
