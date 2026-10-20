import '/utils/inventory_balance_service.dart';
import '/utils/inventory_batch_support.dart';
import '/utils/ledger_scope.dart';
import '/utils/order_lifecycle_support.dart';

class InventoryValuationRow {
  const InventoryValuationRow({
    required this.productId,
    required this.warehouseId,
    required this.ledgerScope,
    required this.physicalQty,
    required this.reservedQty,
    required this.availableQty,
    required this.stockValue,
  });

  final String productId;
  final String warehouseId;
  final LedgerScope ledgerScope;
  final double physicalQty;
  final double reservedQty;
  final double availableQty;
  final double stockValue;
}

class InventoryValuationService {
  const InventoryValuationService({
    InventoryBalanceService inventoryBalanceService =
        const InventoryBalanceService(),
  }) : _inventoryBalanceService = inventoryBalanceService;

  final InventoryBalanceService _inventoryBalanceService;

  double getStockQty({
    required List<InventoryBatchEntry> batches,
    required LedgerScope ledgerScope,
    String? productId,
    String? warehouseId,
  }) {
    return _filterBatches(
      batches: batches,
      ledgerScope: ledgerScope,
      productId: productId,
      warehouseId: warehouseId,
    ).fold<double>(0, (total, batch) => total + batch.qtyRemaining);
  }

  double getReservedQty({
    required List<InventoryReservationEntry> reservations,
    required LedgerScope ledgerScope,
    String? productId,
    String? warehouseId,
  }) {
    return reservations
        .where((reservation) => reservation.ledgerScope.matches(ledgerScope))
        .where((reservation) =>
            productId == null || reservation.productId == productId)
        .where((reservation) =>
            warehouseId == null || reservation.warehouseId == warehouseId)
        .fold<double>(
          0,
          (total, reservation) =>
              total + reservation.openReservedQty,
        );
  }

  double getAvailableQty({
    required List<InventoryBatchEntry> batches,
    required List<InventoryReservationEntry> reservations,
    required LedgerScope ledgerScope,
    String? productId,
    String? warehouseId,
  }) {
    final physical = getStockQty(
      batches: batches,
      ledgerScope: ledgerScope,
      productId: productId,
      warehouseId: warehouseId,
    );
    final reserved = getReservedQty(
      reservations: reservations,
      ledgerScope: ledgerScope,
      productId: productId,
      warehouseId: warehouseId,
    );
    final available = physical - reserved;
    return available < 0 ? 0 : available;
  }

  double getStockValue({
    required List<InventoryBatchEntry> batches,
    required LedgerScope ledgerScope,
    String? productId,
    String? warehouseId,
  }) {
    return _filterBatches(
      batches: batches,
      ledgerScope: ledgerScope,
      productId: productId,
      warehouseId: warehouseId,
    ).fold<double>(0, (total, batch) {
      final qty = batch.qtyRemaining < 0 ? 0 : batch.qtyRemaining;
      return total + (qty * batch.unitCost);
    });
  }

  double getTotalInventoryValue({
    required List<InventoryBatchEntry> batches,
    required LedgerScope ledgerScope,
  }) {
    return getStockValue(
      batches: batches,
      ledgerScope: ledgerScope,
    );
  }

  List<InventoryValuationRow> buildWarehouseValuationRows({
    required List<InventoryBatchEntry> batches,
    required List<InventoryReservationEntry> reservations,
    required LedgerScope ledgerScope,
  }) {
    final keys = <String>{};
    for (final batch in batches) {
      if (!batch.ledgerScope.matches(ledgerScope)) continue;
      keys.add('${batch.productId}::${batch.warehouseId}');
    }
    for (final reservation in reservations) {
      if (!reservation.ledgerScope.matches(ledgerScope)) continue;
      keys.add('${reservation.productId}::${reservation.warehouseId}');
    }
    final rows = keys.map((key) {
      final parts = key.split('::');
      final productId = parts.first;
      final warehouseId = parts.last;
      final physicalQty = getStockQty(
        batches: batches,
        ledgerScope: ledgerScope,
        productId: productId,
        warehouseId: warehouseId,
      );
      final reservedQty = _inventoryBalanceService.getReservedQty(
        reservations: reservations,
        productId: productId,
        warehouseId: warehouseId,
        ledgerScope: ledgerScope,
      );
      final availableQty = physicalQty - reservedQty;
      return InventoryValuationRow(
        productId: productId,
        warehouseId: warehouseId,
        ledgerScope: ledgerScope,
        physicalQty: physicalQty,
        reservedQty: reservedQty,
        availableQty: availableQty < 0 ? 0 : availableQty,
        stockValue: getStockValue(
          batches: batches,
          ledgerScope: ledgerScope,
          productId: productId,
          warehouseId: warehouseId,
        ),
      );
    }).toList(growable: false)
      ..sort((a, b) {
        final warehouseCompare = a.warehouseId.compareTo(b.warehouseId);
        if (warehouseCompare != 0) return warehouseCompare;
        return a.productId.compareTo(b.productId);
      });
    return rows;
  }

  List<InventoryBatchEntry> _filterBatches({
    required List<InventoryBatchEntry> batches,
    required LedgerScope ledgerScope,
    String? productId,
    String? warehouseId,
  }) {
    return batches
        .where((batch) => batch.ledgerScope.matches(ledgerScope))
        .where((batch) => productId == null || batch.productId == productId)
        .where((batch) => warehouseId == null || batch.warehouseId == warehouseId)
        .toList(growable: false);
  }
}
