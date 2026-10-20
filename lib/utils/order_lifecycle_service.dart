import 'package:cloud_firestore/cloud_firestore.dart';

import '/utils/app_money_format.dart';
import '/utils/country_profile.dart';
import '/utils/ledger_scope.dart';
import '/utils/order_lifecycle_support.dart';
import '/utils/sale_flow_support.dart';

double _num(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

String _string(dynamic value) => value?.toString().trim() ?? '';

class OrderLifecycleWritePlan {
  const OrderLifecycleWritePlan({
    required this.orderRef,
    required this.orderData,
    required this.orderItemWrites,
    required this.reservationWrites,
    required this.shipmentWrites,
    required this.paymentWrites,
    required this.orderUpdates,
  });

  final DocumentReference orderRef;
  final Map<String, dynamic> orderData;
  final List<SaleFlowDocWrite> orderItemWrites;
  final List<SaleFlowDocWrite> reservationWrites;
  final List<SaleFlowDocWrite> shipmentWrites;
  final List<SaleFlowDocWrite> paymentWrites;
  final List<SaleFlowDocWrite> orderUpdates;
}

class OrderShipmentWritePlan {
  const OrderShipmentWritePlan({
    required this.salePlan,
    required this.reservationWrites,
  });

  final SaleFlowWritePlan salePlan;
  final List<SaleFlowDocWrite> reservationWrites;
}

Future<OrderLifecycleWritePlan> buildCreateOrderWritePlan({
  required FirebaseFirestore firestore,
  required String companyId,
  required String customerId,
  required String customerName,
  required LedgerScope ledgerScope,
  required List<Map<String, dynamic>> items,
  String notes = '',
  String? currency,
}) async {
  if (items.isEmpty) {
    throw const OrderLifecycleException('Order items are required');
  }
  final orderRef = firestore.collection('customer_orders').doc();
  final orderItemWrites = <SaleFlowDocWrite>[];
  final resolvedCurrency = await _resolveCompanyCurrency(
    firestore: firestore,
    companyId: companyId,
    explicitCurrency: currency,
  );
  double totalAmount = 0;
  var warehouseId = '';
  var warehouseName = '';

  for (final item in items) {
    final itemRef = firestore.collection('customer_order_items').doc();
    final qty = _num(item['qty'] ?? item['quantity']);
    final unitPrice = _num(item['sale_price'] ?? item['price']);
    if (qty <= 0) {
      throw const OrderLifecycleException(
          'Order item quantity must be positive');
    }
    totalAmount += qty * unitPrice;
    warehouseId = warehouseId.isEmpty
        ? _string(item['warehouse_id'] ?? item['warehouse'])
        : warehouseId;
    warehouseName = warehouseName.isEmpty
        ? _string(item['warehouse_name'] ?? item['warehouse'])
        : warehouseName;
    orderItemWrites.add(
      SaleFlowDocWrite(
        itemRef,
        buildOrderItemPayload(
          companyId: companyId,
          orderId: orderRef.id,
          itemKind: _string(item['item_kind']).isEmpty
              ? 'product'
              : _string(item['item_kind']),
          productId: _string(item['item_kind']) == 'service'
              ? ''
              : _string(item['id']),
          serviceId: _string(item['item_kind']) == 'service'
              ? _string(item['id'])
              : '',
          productName: _string(item['name']),
          warehouseId: _string(item['warehouse_id'] ?? item['warehouse']),
          warehouseName: _string(item['warehouse_name'] ?? item['warehouse']),
          ledgerScope: ledgerScope,
          quantityOrdered: qty,
          unitPrice: unitPrice,
        ),
      ),
    );
  }

  return OrderLifecycleWritePlan(
    orderRef: orderRef,
    orderData: buildCustomerOrderPayload(
      companyId: companyId,
      orderNumber: orderRef.id,
      customerId: customerId,
      customerName: customerName,
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      ledgerScope: ledgerScope,
      status: OrderStatus.newOrder,
      totalAmount: totalAmount,
      currency: resolvedCurrency,
      notes: notes,
    ),
    orderItemWrites: orderItemWrites,
    reservationWrites: const [],
    shipmentWrites: const [],
    paymentWrites: const [],
    orderUpdates: const [],
  );
}

Future<String> _resolveCompanyCurrency({
  required FirebaseFirestore firestore,
  required String companyId,
  String? explicitCurrency,
}) async {
  final explicit = normalizeCurrencyCode(explicitCurrency, fallback: '');
  if (explicit.isNotEmpty) return explicit;
  try {
    final snap =
        await firestore.collection('company_profile').doc(companyId).get();
    final profileData = snap.data() ?? const <String, dynamic>{};
    final profile = countryProfileFromData(profileData);
    return companyCurrencyFromProfileData(
      profileData,
      fallback: profile.baseCurrency,
    );
  } catch (_) {
    return 'KZT';
  }
}

Future<OrderLifecycleWritePlan> buildReserveOrderWritePlan({
  required FirebaseFirestore firestore,
  required String companyId,
  required String orderId,
  List<Map<String, dynamic>>? orderItemsOverride,
  List<Map<String, dynamic>>? inventoryBatchesOverride,
  List<Map<String, dynamic>>? reservationsOverride,
}) async {
  final orderRef = firestore.collection('customer_orders').doc(orderId.trim());
  if (orderId.trim().isEmpty) {
    throw const OrderLifecycleException('Order id is required');
  }

  final orderItemsData = orderItemsOverride ??
      (await firestore
              .collection('customer_order_items')
              .where('idCompany', isEqualTo: companyId)
              .where('order_id', isEqualTo: orderId.trim())
              .get())
          .docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
  if (orderItemsData.isEmpty) {
    throw const OrderLifecycleException('Order items not found');
  }

  final reservationsData = reservationsOverride ??
      (await firestore
              .collection('inventory_reservations')
              .where('idCompany', isEqualTo: companyId)
              .where('order_id', isEqualTo: orderId.trim())
              .get())
          .docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

  final inventoryBatchesData = inventoryBatchesOverride ??
      (await firestore
              .collection('inventory_batches')
              .where('idCompany', isEqualTo: companyId)
              .get())
          .docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

  final orderItems = orderItemsData
      .map(OrderItemLifecycleEntry.fromMap)
      .toList(growable: false);
  final reservations = reservationsData
      .map(InventoryReservationEntry.fromMap)
      .toList(growable: false);

  final allocations = reserveInventoryForOrderItems(
    orderItems: orderItems,
    inventoryBatches: inventoryBatchesData,
    existingReservations: reservations,
  );

  final reservationWrites = <SaleFlowDocWrite>[];
  final reservedByItem = <String, double>{};
  for (final allocation in allocations) {
    final reservationRef = firestore.collection('inventory_reservations').doc();
    reservedByItem.update(
      allocation.orderItemId,
      (value) => value + allocation.quantityReserved,
      ifAbsent: () => allocation.quantityReserved,
    );
    reservationWrites.add(
      SaleFlowDocWrite(
        reservationRef,
        buildInventoryReservationPayload(
          companyId: companyId,
          orderId: orderId,
          orderItemId: allocation.orderItemId,
          productId: allocation.productId,
          warehouseId: allocation.warehouseId,
          ledgerScope: allocation.ledgerScope,
          quantityReserved: allocation.quantityReserved,
          batchId: allocation.batchId,
          status: ReservationStatus.reserved,
        ),
      ),
    );
  }

  final orderUpdates = <SaleFlowDocWrite>[
    SaleFlowDocWrite(
      orderRef,
      <String, dynamic>{
        'status': OrderStatus.reserved.storageValue,
        'reserved_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      merge: true,
    ),
  ];

  final orderItemWrites = orderItems.map((item) {
    final increment = reservedByItem[item.id] ?? 0;
    return SaleFlowDocWrite(
      firestore.collection('customer_order_items').doc(item.id),
      <String, dynamic>{
        'quantity_reserved': item.quantityReserved + increment,
        'updated_at': FieldValue.serverTimestamp(),
      },
      merge: true,
    );
  }).toList(growable: false);

  return OrderLifecycleWritePlan(
    orderRef: orderRef,
    orderData: const {},
    orderItemWrites: orderItemWrites,
    reservationWrites: reservationWrites,
    shipmentWrites: const [],
    paymentWrites: const [],
    orderUpdates: orderUpdates,
  );
}

Future<OrderLifecycleWritePlan> buildReleaseOrderReservationWritePlan({
  required FirebaseFirestore firestore,
  required String companyId,
  required String orderId,
  List<Map<String, dynamic>>? orderItemsOverride,
  List<Map<String, dynamic>>? reservationsOverride,
}) async {
  final orderRef = firestore.collection('customer_orders').doc(orderId.trim());
  final orderItemsData = orderItemsOverride ??
      (await firestore
              .collection('customer_order_items')
              .where('idCompany', isEqualTo: companyId)
              .where('order_id', isEqualTo: orderId.trim())
              .get())
          .docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
  final reservationsData = reservationsOverride ??
      (await firestore
              .collection('inventory_reservations')
              .where('idCompany', isEqualTo: companyId)
              .where('order_id', isEqualTo: orderId.trim())
              .get())
          .docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

  final orderItems = orderItemsData
      .map(OrderItemLifecycleEntry.fromMap)
      .toList(growable: false);
  final reservations = reservationsData
      .map(InventoryReservationEntry.fromMap)
      .toList(growable: false);
  final released = releaseReservations(
    reservations: reservations,
    orderId: orderId,
  );

  final reservationWrites = <SaleFlowDocWrite>[];
  final releasedByItem = <String, double>{};
  for (final reservation in released) {
    if (reservation.status != ReservationStatus.released) continue;
    final releasedQty = (reservation.quantityReleased -
            (reservations
                .firstWhere((item) => item.id == reservation.id)
                .quantityReleased))
        .clamp(0, double.infinity)
        .toDouble();
    if (releasedQty > 0) {
      releasedByItem.update(
        reservation.orderItemId,
        (value) => value + releasedQty,
        ifAbsent: () => releasedQty,
      );
    }
    reservationWrites.add(
      SaleFlowDocWrite(
        firestore.collection('inventory_reservations').doc(reservation.id),
        <String, dynamic>{
          'quantity_released': reservation.quantityReleased,
          'status': reservation.status.storageValue,
          'released_at': FieldValue.serverTimestamp(),
        },
        merge: true,
      ),
    );
  }

  final orderItemWrites = orderItems.map((item) {
    final releasedQty = releasedByItem[item.id] ?? 0;
    final nextReserved = (item.quantityReserved - releasedQty)
        .clamp(0, double.infinity)
        .toDouble();
    return SaleFlowDocWrite(
      firestore.collection('customer_order_items').doc(item.id),
      <String, dynamic>{
        'quantity_reserved': nextReserved,
        'updated_at': FieldValue.serverTimestamp(),
      },
      merge: true,
    );
  }).toList(growable: false);

  final nextStatus = deriveOrderStatus(
    items: orderItems
        .map((item) => OrderItemLifecycleEntry(
              id: item.id,
              orderId: item.orderId,
              itemKind: item.itemKind,
              productId: item.productId,
              serviceId: item.serviceId,
              productName: item.productName,
              quantityOrdered: item.quantityOrdered,
              quantityReserved:
                  (item.quantityReserved - (releasedByItem[item.id] ?? 0))
                      .clamp(0, double.infinity)
                      .toDouble(),
              quantityShipped: item.quantityShipped,
              unitPrice: item.unitPrice,
              lineAmount: item.lineAmount,
              warehouseId: item.warehouseId,
              warehouseName: item.warehouseName,
              ledgerScope: item.ledgerScope,
            ))
        .toList(growable: false),
    reservations: released,
  );

  return OrderLifecycleWritePlan(
    orderRef: orderRef,
    orderData: const {},
    orderItemWrites: orderItemWrites,
    reservationWrites: reservationWrites,
    shipmentWrites: const [],
    paymentWrites: const [],
    orderUpdates: [
      SaleFlowDocWrite(
        orderRef,
        <String, dynamic>{
          'status': nextStatus.storageValue,
          'updated_at': FieldValue.serverTimestamp(),
        },
        merge: true,
      ),
    ],
  );
}

Future<OrderShipmentWritePlan> buildShipOrderWritePlan({
  required FirebaseFirestore firestore,
  required String companyId,
  required String orderId,
  List<Map<String, dynamic>>? orderOverride,
  List<Map<String, dynamic>>? orderItemsOverride,
  List<Map<String, dynamic>>? reservationsOverride,
}) async {
  final trimmedOrderId = orderId.trim();
  if (trimmedOrderId.isEmpty) {
    throw const OrderLifecycleException('Order id is required');
  }
  final orderData = orderOverride ??
      <Map<String, dynamic>>[
        {
          'id': trimmedOrderId,
          ...?(await firestore
                  .collection('customer_orders')
                  .doc(trimmedOrderId)
                  .get())
              .data(),
        },
      ];
  if (orderData.isEmpty ||
      orderData.first['idCompany'] == null && companyId.isEmpty) {
    throw const OrderLifecycleException('Order not found');
  }
  final order = orderData.first;
  final orderItemsData = orderItemsOverride ??
      (await firestore
              .collection('customer_order_items')
              .where('idCompany', isEqualTo: companyId)
              .where('order_id', isEqualTo: trimmedOrderId)
              .get())
          .docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
  if (orderItemsData.isEmpty) {
    throw const OrderLifecycleException('Order items not found');
  }
  final reservationsData = reservationsOverride ??
      (await firestore
              .collection('inventory_reservations')
              .where('idCompany', isEqualTo: companyId)
              .where('order_id', isEqualTo: trimmedOrderId)
              .get())
          .docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

  final orderItems = orderItemsData
      .map(OrderItemLifecycleEntry.fromMap)
      .where((item) => item.quantityRemainingToShip > 0)
      .toList(growable: false);
  if (orderItems.isEmpty) {
    throw const OrderLifecycleException('Nothing to ship for order');
  }

  final cart = orderItems
      .map((item) => <String, dynamic>{
            'id': item.itemKind == 'service' ? item.serviceId : item.productId,
            'name': item.productName,
            'qty': item.quantityRemainingToShip,
            'sale_price': item.unitPrice,
            'warehouse_id': item.warehouseId,
            'warehouse_name': item.warehouseName,
            'item_kind': item.itemKind,
            'order_item_id': item.id,
            'existing_quantity_shipped': item.quantityShipped,
            'existing_quantity_reserved': item.quantityReserved,
          })
      .toList(growable: false);

  final totalAmount = orderItems.fold<double>(
    0,
    (total, item) => total + (item.quantityRemainingToShip * item.unitPrice),
  );
  final ledgerScope = ledgerScopeFromData(order);

  final salePlan = await buildCashSaleWritePlan(
    firestore: firestore,
    companyId: companyId,
    cashierId: '',
    cashierName: 'Order shipment',
    shopId: '',
    shopName: '',
    cashRegisterId: '',
    cashRegisterName: '',
    clientId: _string(order['customer_id']),
    clientName: _string(order['customer_name']),
    amount: totalAmount,
    discount: 0,
    paymentMethod: 'debt',
    typeUchet: ledgerScope.legacyTypeUchet,
    ledgerScope: ledgerScope,
    cart: cart,
    accountReference: null,
    accountTitle: 'Дебиторка',
    nextCashSales: 0,
    nextCardSales: 0,
    nextTransactions: 0,
    existingOrderId: trimmedOrderId,
  );

  final reservationEntries = reservationsData
      .map(InventoryReservationEntry.fromMap)
      .toList(growable: false);
  final reservationWrites = <SaleFlowDocWrite>[];
  for (final item in orderItems) {
    if (item.itemKind == 'service') continue;
    final consumptions = consumeReservationsForShipment(
      orderItemId: item.id,
      shippedQty: item.quantityRemainingToShip,
      reservations: reservationEntries,
    );
    for (final consumption in consumptions) {
      if (consumption.reservationId.isEmpty ||
          consumption.quantityConsumed <= 0) {
        continue;
      }
      final reservation = reservationEntries.firstWhere(
        (entry) => entry.id == consumption.reservationId,
      );
      final nextConsumed =
          reservation.quantityConsumed + consumption.quantityConsumed;
      final nextOpen = (reservation.quantityReserved -
              reservation.quantityReleased -
              nextConsumed)
          .clamp(0, double.infinity)
          .toDouble();
      reservationWrites.add(
        SaleFlowDocWrite(
          firestore.collection('inventory_reservations').doc(reservation.id),
          <String, dynamic>{
            'quantity_consumed': nextConsumed,
            'status': nextOpen <= 0
                ? ReservationStatus.consumed.storageValue
                : ReservationStatus.reserved.storageValue,
            'consumed_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          },
          merge: true,
        ),
      );
    }
  }

  return OrderShipmentWritePlan(
    salePlan: salePlan,
    reservationWrites: reservationWrites,
  );
}
