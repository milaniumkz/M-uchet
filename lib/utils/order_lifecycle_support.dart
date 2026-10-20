import 'package:cloud_firestore/cloud_firestore.dart';

import '/utils/country_profile.dart';
import '/utils/ledger_scope.dart';

double _num(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

String _string(dynamic value) => value?.toString().trim() ?? '';

DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

enum OrderStatus {
  newOrder('NEW'),
  reserved('RESERVED'),
  shipped('SHIPPED'),
  closed('CLOSED'),
  cancelled('CANCELLED');

  const OrderStatus(this.storageValue);
  final String storageValue;
}

enum ReservationStatus {
  reserved('RESERVED'),
  released('RELEASED'),
  consumed('CONSUMED');

  const ReservationStatus(this.storageValue);
  final String storageValue;
}

OrderStatus orderStatusFromValue(dynamic raw) {
  final normalized = _string(raw).toUpperCase();
  return OrderStatus.values.firstWhere(
    (value) => value.storageValue == normalized,
    orElse: () => OrderStatus.newOrder,
  );
}

ReservationStatus reservationStatusFromValue(dynamic raw) {
  final normalized = _string(raw).toUpperCase();
  return ReservationStatus.values.firstWhere(
    (value) => value.storageValue == normalized,
    orElse: () => ReservationStatus.reserved,
  );
}

class OrderLifecycleException implements Exception {
  const OrderLifecycleException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OrderItemLifecycleEntry {
  const OrderItemLifecycleEntry({
    required this.id,
    required this.orderId,
    required this.itemKind,
    required this.productId,
    required this.serviceId,
    required this.productName,
    required this.quantityOrdered,
    required this.quantityReserved,
    required this.quantityShipped,
    required this.unitPrice,
    required this.lineAmount,
    required this.warehouseId,
    required this.warehouseName,
    required this.ledgerScope,
  });

  final String id;
  final String orderId;
  final String itemKind;
  final String productId;
  final String serviceId;
  final String productName;
  final double quantityOrdered;
  final double quantityReserved;
  final double quantityShipped;
  final double unitPrice;
  final double lineAmount;
  final String warehouseId;
  final String warehouseName;
  final LedgerScope ledgerScope;

  factory OrderItemLifecycleEntry.fromMap(Map<String, dynamic> data) {
    return OrderItemLifecycleEntry(
      id: _string(data['id']),
      orderId: _string(data['order_id'] ?? data['orderId']),
      itemKind: _string(data['item_type'] ?? data['itemKind']).isEmpty
          ? 'product'
          : _string(data['item_type'] ?? data['itemKind']),
      productId: _string(data['product_id'] ?? data['productId']),
      serviceId: _string(data['service_id'] ?? data['serviceId']),
      productName: _string(data['product_name'] ?? data['productName']),
      quantityOrdered: _num(
        data['quantity_ordered'] ?? data['quantityOrdered'] ?? data['qty'],
      ),
      quantityReserved: _num(
        data['quantity_reserved'] ?? data['quantityReserved'],
      ),
      quantityShipped: _num(
        data['quantity_shipped'] ?? data['quantityShipped'],
      ),
      unitPrice: _num(data['unit_price'] ?? data['unitPrice']),
      lineAmount: _num(data['line_amount'] ?? data['lineAmount']),
      warehouseId: _string(data['warehouse_id'] ?? data['warehouseId']),
      warehouseName: _string(data['warehouse_name'] ?? data['warehouseName']),
      ledgerScope: ledgerScopeFromData(data),
    );
  }

  double get quantityToReserve =>
      (quantityOrdered - quantityReserved).clamp(0, double.infinity);

  double get quantityRemainingToShip =>
      (quantityOrdered - quantityShipped).clamp(0, double.infinity);
}

class InventoryReservationEntry {
  const InventoryReservationEntry({
    required this.id,
    required this.orderId,
    required this.orderItemId,
    required this.productId,
    required this.warehouseId,
    required this.batchId,
    required this.ledgerScope,
    required this.quantityReserved,
    required this.quantityReleased,
    required this.quantityConsumed,
    required this.status,
    required this.createdAt,
    this.releasedAt,
    this.consumedAt,
  });

  final String id;
  final String orderId;
  final String orderItemId;
  final String productId;
  final String warehouseId;
  final String batchId;
  final LedgerScope ledgerScope;
  final double quantityReserved;
  final double quantityReleased;
  final double quantityConsumed;
  final ReservationStatus status;
  final DateTime? createdAt;
  final DateTime? releasedAt;
  final DateTime? consumedAt;

  factory InventoryReservationEntry.fromMap(Map<String, dynamic> data) {
    return InventoryReservationEntry(
      id: _string(data['id']),
      orderId: _string(data['order_id'] ?? data['orderId']),
      orderItemId: _string(data['order_item_id'] ?? data['orderItemId']),
      productId: _string(data['product_id'] ?? data['productId']),
      warehouseId: _string(data['warehouse_id'] ?? data['warehouseId']),
      batchId: _string(data['batch_id'] ?? data['batchId']),
      ledgerScope: ledgerScopeFromData(data),
      quantityReserved: _num(
        data['quantity_reserved'] ?? data['quantityReserved'] ?? data['qty'],
      ),
      quantityReleased: _num(
        data['quantity_released'] ?? data['quantityReleased'],
      ),
      quantityConsumed: _num(
        data['quantity_consumed'] ?? data['quantityConsumed'],
      ),
      status: reservationStatusFromValue(data['status']),
      createdAt: _date(data['created_at'] ?? data['createdAt']),
      releasedAt: _date(data['released_at'] ?? data['releasedAt']),
      consumedAt: _date(data['consumed_at'] ?? data['consumedAt']),
    );
  }

  double get openReservedQty =>
      (quantityReserved - quantityReleased - quantityConsumed)
          .clamp(0, double.infinity);
}

class InventoryReservationAllocation {
  const InventoryReservationAllocation({
    required this.orderItemId,
    required this.productId,
    required this.warehouseId,
    required this.batchId,
    required this.ledgerScope,
    required this.quantityReserved,
  });

  final String orderItemId;
  final String productId;
  final String warehouseId;
  final String batchId;
  final LedgerScope ledgerScope;
  final double quantityReserved;
}

String _reservationPoolKey({
  required String productId,
  required String warehouseId,
  required LedgerScope ledgerScope,
}) {
  return '${ledgerScope.storageValue}|$warehouseId|$productId';
}

class ShipmentReservationConsumption {
  const ShipmentReservationConsumption({
    required this.reservationId,
    required this.quantityConsumed,
    required this.remainingToConsumePhysically,
  });

  final String reservationId;
  final double quantityConsumed;
  final double remainingToConsumePhysically;
}

double computeReservedQty({
  required List<InventoryReservationEntry> reservations,
  required String productId,
  required String warehouseId,
  required LedgerScope ledgerScope,
}) {
  return reservations.fold<double>(0, (total, reservation) {
    if (reservation.productId != productId ||
        reservation.warehouseId != warehouseId ||
        !reservation.ledgerScope.matches(ledgerScope)) {
      return total;
    }
    return total + reservation.openReservedQty;
  });
}

double computeAvailableQty({
  required double physicalQty,
  required List<InventoryReservationEntry> reservations,
  required String productId,
  required String warehouseId,
  required LedgerScope ledgerScope,
}) {
  return (physicalQty -
          computeReservedQty(
            reservations: reservations,
            productId: productId,
            warehouseId: warehouseId,
            ledgerScope: ledgerScope,
          ))
      .clamp(0, double.infinity);
}

List<InventoryReservationAllocation> reserveInventoryForOrderItems({
  required List<OrderItemLifecycleEntry> orderItems,
  required List<Map<String, dynamic>> inventoryBatches,
  required List<InventoryReservationEntry> existingReservations,
}) {
  final allocations = <InventoryReservationAllocation>[];
  final batchAvailability = <String, double>{};
  final batchMetadata = <String, Map<String, dynamic>>{};
  final unassignedReservedPool = <String, double>{};

  for (final raw in inventoryBatches) {
    final batchId = _string(raw['id']);
    if (batchId.isEmpty) continue;
    final ledgerScope = ledgerScopeFromData(raw);
    final productId = _string(raw['product_id']);
    final warehouseId = _string(raw['warehouse_id'] ?? raw['warehouseId']);
    final qtyRemaining = _num(raw['qty_remaining'] ?? raw['qtyRemaining']);
    final reservedForBatch =
        existingReservations.fold<double>(0, (total, reservation) {
      if (reservation.batchId != batchId ||
          reservation.productId != productId ||
          reservation.warehouseId != warehouseId ||
          !reservation.ledgerScope.matches(ledgerScope)) {
        return total;
      }
      return total + reservation.openReservedQty;
    });
    final poolKey = _reservationPoolKey(
      productId: productId,
      warehouseId: warehouseId,
      ledgerScope: ledgerScope,
    );
    final unassignedReserved =
        existingReservations.fold<double>(0, (total, reservation) {
      if (reservation.batchId.isNotEmpty ||
          reservation.productId != productId ||
          reservation.warehouseId != warehouseId ||
          !reservation.ledgerScope.matches(ledgerScope)) {
        return total;
      }
      return total + reservation.openReservedQty;
    });
    unassignedReservedPool[poolKey] = unassignedReserved;
    var available =
        (qtyRemaining - reservedForBatch).clamp(0, double.infinity).toDouble();
    final pooledReserved = unassignedReservedPool[poolKey] ?? 0;
    if (pooledReserved > 0 && available > 0) {
      final applied = available >= pooledReserved ? pooledReserved : available;
      available -= applied;
      unassignedReservedPool[poolKey] = pooledReserved - applied;
    }
    batchAvailability[batchId] = available;
    batchMetadata[batchId] = raw;
  }

  for (final item in orderItems) {
    var remaining = item.quantityToReserve;
    if (remaining <= 0) continue;

    final matchingBatches = batchMetadata.entries.where((entry) {
      final raw = entry.value;
      return _string(raw['product_id']) == item.productId &&
          _string(raw['warehouse_id'] ?? raw['warehouseId']) ==
              item.warehouseId &&
          ledgerScopeFromData(raw).matches(item.ledgerScope);
    }).toList()
      ..sort((a, b) {
        final ad = _date(a.value['received_at'] ?? a.value['created_at'])
                ?.millisecondsSinceEpoch ??
            0;
        final bd = _date(b.value['received_at'] ?? b.value['created_at'])
                ?.millisecondsSinceEpoch ??
            0;
        return ad.compareTo(bd);
      });

    for (final batch in matchingBatches) {
      if (remaining <= 0) break;
      final batchId = batch.key;
      final available = batchAvailability[batchId] ?? 0;
      if (available <= 0) continue;
      final reserved = available >= remaining ? remaining : available;
      allocations.add(
        InventoryReservationAllocation(
          orderItemId: item.id,
          productId: item.productId,
          warehouseId: item.warehouseId,
          batchId: batchId,
          ledgerScope: item.ledgerScope,
          quantityReserved: reserved,
        ),
      );
      batchAvailability[batchId] = available - reserved;
      remaining -= reserved;
    }

    if (remaining > 1e-9) {
      throw OrderLifecycleException(
        'Insufficient available stock for ${item.productName.isEmpty ? item.productId : item.productName}',
      );
    }
  }

  return allocations;
}

List<InventoryReservationEntry> releaseReservations({
  required List<InventoryReservationEntry> reservations,
  String? orderId,
  String? reservationId,
  DateTime? releasedAt,
}) {
  final released = releasedAt ?? DateTime.now();
  return reservations.map((reservation) {
    final shouldRelease =
        (reservationId != null && reservation.id == reservationId.trim()) ||
            (reservationId == null &&
                orderId != null &&
                reservation.orderId == orderId.trim());
    if (!shouldRelease || reservation.openReservedQty <= 0) {
      return reservation;
    }
    return InventoryReservationEntry(
      id: reservation.id,
      orderId: reservation.orderId,
      orderItemId: reservation.orderItemId,
      productId: reservation.productId,
      warehouseId: reservation.warehouseId,
      batchId: reservation.batchId,
      ledgerScope: reservation.ledgerScope,
      quantityReserved: reservation.quantityReserved,
      quantityReleased:
          reservation.quantityReleased + reservation.openReservedQty,
      quantityConsumed: reservation.quantityConsumed,
      status: ReservationStatus.released,
      createdAt: reservation.createdAt,
      releasedAt: released,
      consumedAt: reservation.consumedAt,
    );
  }).toList(growable: false);
}

List<ShipmentReservationConsumption> consumeReservationsForShipment({
  required String orderItemId,
  required double shippedQty,
  required List<InventoryReservationEntry> reservations,
}) {
  var remaining = shippedQty;
  final result = <ShipmentReservationConsumption>[];
  final matching = reservations
      .where((reservation) =>
          reservation.orderItemId == orderItemId &&
          reservation.openReservedQty > 0)
      .toList()
    ..sort((a, b) {
      final ad = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bd = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return ad.compareTo(bd);
    });

  for (final reservation in matching) {
    if (remaining <= 0) break;
    final consumed = reservation.openReservedQty >= remaining
        ? remaining
        : reservation.openReservedQty;
    remaining -= consumed;
    result.add(
      ShipmentReservationConsumption(
        reservationId: reservation.id,
        quantityConsumed: consumed,
        remainingToConsumePhysically: remaining,
      ),
    );
  }

  if (remaining < 0) remaining = 0;
  if (result.isEmpty && shippedQty > 0) {
    result.add(
      ShipmentReservationConsumption(
        reservationId: '',
        quantityConsumed: 0,
        remainingToConsumePhysically: shippedQty,
      ),
    );
  } else if (result.isNotEmpty) {
    final last = result.removeLast();
    result.add(
      ShipmentReservationConsumption(
        reservationId: last.reservationId,
        quantityConsumed: last.quantityConsumed,
        remainingToConsumePhysically: remaining,
      ),
    );
  }
  return result;
}

OrderStatus deriveOrderStatus({
  required List<OrderItemLifecycleEntry> items,
  required List<InventoryReservationEntry> reservations,
  bool cancelled = false,
  bool fullyPaid = false,
}) {
  if (cancelled) return OrderStatus.cancelled;
  final totalOrdered =
      items.fold<double>(0, (total, item) => total + item.quantityOrdered);
  final totalShipped =
      items.fold<double>(0, (total, item) => total + item.quantityShipped);
  final totalReserved = reservations.fold<double>(
    0,
    (total, reservation) => total + reservation.openReservedQty,
  );
  if (totalOrdered > 0 && totalShipped >= totalOrdered - 1e-9) {
    return fullyPaid ? OrderStatus.closed : OrderStatus.shipped;
  }
  if (totalReserved > 0) return OrderStatus.reserved;
  return OrderStatus.newOrder;
}

Map<String, dynamic> buildCustomerOrderPayload({
  required String companyId,
  required String orderNumber,
  required String customerId,
  required String customerName,
  required String warehouseId,
  required String warehouseName,
  required LedgerScope ledgerScope,
  required OrderStatus status,
  required double totalAmount,
  String currency = 'KZT',
  String notes = '',
  DateTime? reservedAt,
  DateTime? shippedAt,
  DateTime? closedAt,
}) {
  return <String, dynamic>{
    'idCompany': companyId.trim(),
    'order_number': orderNumber.trim(),
    'customer_id': customerId.trim(),
    'customer_name': customerName.trim(),
    'warehouse_id': warehouseId.trim(),
    'warehouse_name': warehouseName.trim(),
    ...ledgerScopeFields(ledgerScope: ledgerScope),
    'status': status.storageValue,
    'total_amount': totalAmount,
    'currency': normalizeCurrencyCode(currency),
    'notes': notes.trim(),
    'created_at': FieldValue.serverTimestamp(),
    'updated_at': FieldValue.serverTimestamp(),
    'reserved_at': reservedAt == null ? null : Timestamp.fromDate(reservedAt),
    'shipped_at': shippedAt == null ? null : Timestamp.fromDate(shippedAt),
    'closed_at': closedAt == null ? null : Timestamp.fromDate(closedAt),
  }..removeWhere((key, value) => value == null);
}

Map<String, dynamic> buildOrderItemPayload({
  required String companyId,
  required String orderId,
  required String productId,
  required String productName,
  String itemKind = 'product',
  String serviceId = '',
  required String warehouseId,
  required String warehouseName,
  required LedgerScope ledgerScope,
  required double quantityOrdered,
  double quantityReserved = 0,
  double quantityShipped = 0,
  required double unitPrice,
}) {
  return <String, dynamic>{
    'idCompany': companyId.trim(),
    'order_id': orderId.trim(),
    'item_type': itemKind.trim().isEmpty ? 'product' : itemKind.trim(),
    'product_id': productId.trim(),
    'service_id': serviceId.trim(),
    'product_name': productName.trim(),
    'warehouse_id': warehouseId.trim(),
    'warehouse_name': warehouseName.trim(),
    ...ledgerScopeFields(ledgerScope: ledgerScope),
    'quantity_ordered': quantityOrdered,
    'quantity_reserved': quantityReserved,
    'quantity_shipped': quantityShipped,
    'unit_price': unitPrice,
    'line_amount': quantityOrdered * unitPrice,
    'created_at': FieldValue.serverTimestamp(),
    'updated_at': FieldValue.serverTimestamp(),
  };
}

Map<String, dynamic> buildInventoryReservationPayload({
  required String companyId,
  required String orderId,
  required String orderItemId,
  required String productId,
  required String warehouseId,
  required LedgerScope ledgerScope,
  required double quantityReserved,
  String batchId = '',
  double quantityReleased = 0,
  double quantityConsumed = 0,
  required ReservationStatus status,
  DateTime? releasedAt,
  DateTime? consumedAt,
}) {
  return <String, dynamic>{
    'idCompany': companyId.trim(),
    'order_id': orderId.trim(),
    'order_item_id': orderItemId.trim(),
    'product_id': productId.trim(),
    'warehouse_id': warehouseId.trim(),
    'batch_id': batchId.trim().isEmpty ? null : batchId.trim(),
    ...ledgerScopeFields(ledgerScope: ledgerScope),
    'quantity_reserved': quantityReserved,
    'quantity_released': quantityReleased,
    'quantity_consumed': quantityConsumed,
    'status': status.storageValue,
    'created_at': FieldValue.serverTimestamp(),
    'released_at': releasedAt == null ? null : Timestamp.fromDate(releasedAt),
    'consumed_at': consumedAt == null ? null : Timestamp.fromDate(consumedAt),
  }..removeWhere((key, value) => value == null);
}

Map<String, dynamic> buildShipmentPayload({
  required String companyId,
  required String orderId,
  required String saleId,
  required LedgerScope ledgerScope,
  required String warehouseId,
  required String warehouseName,
  required double totalAmount,
  required double quantity,
  String status = 'SHIPPED',
  DateTime? shippedAt,
}) {
  return <String, dynamic>{
    'idCompany': companyId.trim(),
    'order_id': orderId.trim(),
    'sale_id': saleId.trim(),
    'warehouse_id': warehouseId.trim(),
    'warehouse_name': warehouseName.trim(),
    ...ledgerScopeFields(ledgerScope: ledgerScope),
    'status': status.trim().isEmpty ? 'SHIPPED' : status.trim().toUpperCase(),
    'total_amount': totalAmount,
    'quantity': quantity,
    'shipped_at': shippedAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(shippedAt),
    'created_at': FieldValue.serverTimestamp(),
    'updated_at': FieldValue.serverTimestamp(),
  };
}

Map<String, dynamic> buildOrderPaymentPayload({
  required String companyId,
  required String orderId,
  required String transactionId,
  required LedgerScope ledgerScope,
  required double amount,
  required String paymentMethod,
  String status = 'POSTED',
  DateTime? paidAt,
}) {
  return <String, dynamic>{
    'idCompany': companyId.trim(),
    'order_id': orderId.trim(),
    'transaction_id': transactionId.trim(),
    ...ledgerScopeFields(ledgerScope: ledgerScope),
    'amount': amount,
    'payment_method': paymentMethod.trim(),
    'status': status.trim().isEmpty ? 'POSTED' : status.trim().toUpperCase(),
    'paid_at': paidAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(paidAt),
    'created_at': FieldValue.serverTimestamp(),
  };
}
