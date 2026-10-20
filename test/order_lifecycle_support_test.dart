import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/inventory_balance_service.dart';
import 'package:uchet_s_d/utils/inventory_batch_support.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';
import 'package:uchet_s_d/utils/order_lifecycle_support.dart';

void main() {
  group('order lifecycle support', () {
    const orderItem = OrderItemLifecycleEntry(
      id: 'item-1',
      orderId: 'order-1',
      itemKind: 'product',
      productId: 'product-1',
      serviceId: '',
      productName: 'Product',
      quantityOrdered: 4,
      quantityReserved: 0,
      quantityShipped: 0,
      unitPrice: 10,
      lineAmount: 40,
      warehouseId: 'wh-1',
      warehouseName: 'Main',
      ledgerScope: LedgerScope.management,
    );

    final batches = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'batch-1',
        'product_id': 'product-1',
        'warehouse_id': 'wh-1',
        'ledger_scope': 'MANAGEMENT',
        'qty_remaining': 3,
        'received_at': DateTime(2024, 1, 1),
      },
      <String, dynamic>{
        'id': 'batch-2',
        'product_id': 'product-1',
        'warehouse_id': 'wh-1',
        'ledger_scope': 'MANAGEMENT',
        'qty_remaining': 3,
        'received_at': DateTime(2024, 1, 2),
      },
      <String, dynamic>{
        'id': 'batch-bu',
        'product_id': 'product-1',
        'warehouse_id': 'wh-1',
        'ledger_scope': 'ACCOUNTING',
        'qty_remaining': 10,
        'received_at': DateTime(2024, 1, 3),
      },
    ];

    test('creates NEW status after order creation', () {
      final status = deriveOrderStatus(
        items: const [orderItem],
        reservations: const [],
      );
      expect(status, OrderStatus.newOrder);
    });

    test('reserves inventory FIFO and transitions to RESERVED', () {
      final allocations = reserveInventoryForOrderItems(
        orderItems: const [orderItem],
        inventoryBatches: batches,
        existingReservations: const [],
      );
      expect(allocations, hasLength(2));
      expect(allocations.first.batchId, 'batch-1');
      expect(allocations.first.quantityReserved, 3);
      expect(allocations.last.batchId, 'batch-2');
      expect(allocations.last.quantityReserved, 1);

      final reservations = allocations
          .asMap()
          .entries
          .map(
            (entry) => InventoryReservationEntry(
              id: 'r-${entry.key}',
              orderId: 'order-1',
              orderItemId: orderItem.id,
              productId: orderItem.productId,
              warehouseId: orderItem.warehouseId,
              batchId: entry.value.batchId,
              ledgerScope: entry.value.ledgerScope,
              quantityReserved: entry.value.quantityReserved,
              quantityReleased: 0,
              quantityConsumed: 0,
              status: ReservationStatus.reserved,
              createdAt: DateTime(2024, 1, 1),
            ),
          )
          .toList();

      final status = deriveOrderStatus(
        items: const [orderItem],
        reservations: reservations,
      );
      expect(status, OrderStatus.reserved);
    });

    test('throws when available stock is insufficient', () {
      expect(
        () => reserveInventoryForOrderItems(
          orderItems: const [
            OrderItemLifecycleEntry(
              id: 'item-2',
              orderId: 'order-1',
              itemKind: 'product',
              productId: 'product-1',
              serviceId: '',
              productName: 'Product',
              quantityOrdered: 20,
              quantityReserved: 0,
              quantityShipped: 0,
              unitPrice: 10,
              lineAmount: 200,
              warehouseId: 'wh-1',
              warehouseName: 'Main',
              ledgerScope: LedgerScope.management,
            ),
          ],
          inventoryBatches: batches,
          existingReservations: const [],
        ),
        throwsA(isA<OrderLifecycleException>()),
      );
    });

    test('available stock decreases while physical stock stays intact', () {
      const service = InventoryBalanceService();
      final normalized = [
        InventoryBatchEntry.fromMap(<String, dynamic>{
          'id': 'batch-1',
          'idCompany': 'company',
          'product_id': 'product-1',
          'product_name': 'Product',
          'warehouse_id': 'wh-1',
          'warehouse_name': 'Main',
          'ledger_scope': 'MANAGEMENT',
          'qty_initial': 5,
          'qty_remaining': 5,
          'unit_cost': 2,
        }),
      ];
      final reservations = [
        InventoryReservationEntry(
          id: 'r-1',
          orderId: 'order-1',
          orderItemId: 'item-1',
          productId: 'product-1',
          warehouseId: 'wh-1',
          batchId: 'batch-1',
          ledgerScope: LedgerScope.management,
          quantityReserved: 2,
          quantityReleased: 0,
          quantityConsumed: 0,
          status: ReservationStatus.reserved,
          createdAt: DateTime(2024, 1, 1),
        ),
      ];
      expect(
        service.getPhysicalQty(
          batches: normalized,
          ledgerScope: LedgerScope.management,
        ),
        5,
      );
      expect(
        service.getReservedQty(
          reservations: reservations,
          productId: 'product-1',
          warehouseId: 'wh-1',
          ledgerScope: LedgerScope.management,
        ),
        2,
      );
      expect(
        service.getAvailableQty(
          batches: normalized,
          ledgerScope: LedgerScope.management,
          productId: 'product-1',
          warehouseId: 'wh-1',
          reservations: reservations,
        ),
        3,
      );
    });

    test('available stock is scoped by product and warehouse', () {
      const service = InventoryBalanceService();
      final normalized = [
        InventoryBatchEntry.fromMap(<String, dynamic>{
          'id': 'batch-1',
          'idCompany': 'company',
          'product_id': 'product-1',
          'product_name': 'Product 1',
          'warehouse_id': 'wh-1',
          'warehouse_name': 'Main',
          'ledger_scope': 'MANAGEMENT',
          'qty_initial': 5,
          'qty_remaining': 5,
          'unit_cost': 2,
        }),
        InventoryBatchEntry.fromMap(<String, dynamic>{
          'id': 'batch-2',
          'idCompany': 'company',
          'product_id': 'product-2',
          'product_name': 'Product 2',
          'warehouse_id': 'wh-2',
          'warehouse_name': 'Other',
          'ledger_scope': 'MANAGEMENT',
          'qty_initial': 100,
          'qty_remaining': 100,
          'unit_cost': 2,
        }),
      ];
      final reservations = [
        InventoryReservationEntry(
          id: 'r-1',
          orderId: 'order-1',
          orderItemId: 'item-1',
          productId: 'product-1',
          warehouseId: 'wh-1',
          batchId: 'batch-1',
          ledgerScope: LedgerScope.management,
          quantityReserved: 2,
          quantityReleased: 0,
          quantityConsumed: 0,
          status: ReservationStatus.reserved,
          createdAt: DateTime(2024, 1, 1),
        ),
      ];

      expect(
        service.getAvailableQty(
          batches: normalized,
          ledgerScope: LedgerScope.management,
          productId: 'product-1',
          warehouseId: 'wh-1',
          reservations: reservations,
        ),
        3,
      );
    });

    test('existing batch-level reservations do not over-subtract every batch', () {
      final allocations = reserveInventoryForOrderItems(
        orderItems: const [
          OrderItemLifecycleEntry(
            id: 'item-3',
            orderId: 'order-1',
            itemKind: 'product',
            productId: 'product-1',
            serviceId: '',
            productName: 'Product',
            quantityOrdered: 3,
            quantityReserved: 0,
            quantityShipped: 0,
            unitPrice: 10,
            lineAmount: 30,
            warehouseId: 'wh-1',
            warehouseName: 'Main',
            ledgerScope: LedgerScope.management,
          ),
        ],
        inventoryBatches: batches,
        existingReservations: [
          InventoryReservationEntry(
            id: 'r-existing',
            orderId: 'order-old',
            orderItemId: 'old-item',
            productId: 'product-1',
            warehouseId: 'wh-1',
            batchId: 'batch-1',
            ledgerScope: LedgerScope.management,
            quantityReserved: 2,
            quantityReleased: 0,
            quantityConsumed: 0,
            status: ReservationStatus.reserved,
            createdAt: DateTime(2024, 1, 1),
          ),
        ],
      );

      expect(allocations, hasLength(2));
      expect(allocations.first.batchId, 'batch-1');
      expect(allocations.first.quantityReserved, 1);
      expect(allocations.last.batchId, 'batch-2');
      expect(allocations.last.quantityReserved, 2);
    });

    test('release reservation restores available stock', () {
      final released = releaseReservations(
        reservations: [
          InventoryReservationEntry(
            id: 'r-1',
            orderId: 'order-1',
            orderItemId: 'item-1',
            productId: 'product-1',
            warehouseId: 'wh-1',
            batchId: 'batch-1',
            ledgerScope: LedgerScope.management,
            quantityReserved: 2,
            quantityReleased: 0,
            quantityConsumed: 0,
            status: ReservationStatus.reserved,
            createdAt: DateTime(2024, 1, 1),
          ),
        ],
        orderId: 'order-1',
      );
      expect(released.first.status, ReservationStatus.released);
      expect(released.first.quantityReleased, 2);
      expect(released.first.openReservedQty, 0);
    });

    test('shipment consumes reservations and transitions to shipped/closed', () {
      final consumptions = consumeReservationsForShipment(
        orderItemId: 'item-1',
        shippedQty: 4,
        reservations: [
          InventoryReservationEntry(
            id: 'r-1',
            orderId: 'order-1',
            orderItemId: 'item-1',
            productId: 'product-1',
            warehouseId: 'wh-1',
            batchId: 'batch-1',
            ledgerScope: LedgerScope.management,
            quantityReserved: 3,
            quantityReleased: 0,
            quantityConsumed: 0,
            status: ReservationStatus.reserved,
            createdAt: DateTime(2024, 1, 1),
          ),
          InventoryReservationEntry(
            id: 'r-2',
            orderId: 'order-1',
            orderItemId: 'item-1',
            productId: 'product-1',
            warehouseId: 'wh-1',
            batchId: 'batch-2',
            ledgerScope: LedgerScope.management,
            quantityReserved: 1,
            quantityReleased: 0,
            quantityConsumed: 0,
            status: ReservationStatus.reserved,
            createdAt: DateTime(2024, 1, 2),
          ),
        ],
      );
      expect(consumptions, hasLength(2));
      expect(consumptions.last.remainingToConsumePhysically, 0);

      final shipped = deriveOrderStatus(
        items: const [
          OrderItemLifecycleEntry(
            id: 'item-1',
            orderId: 'order-1',
            itemKind: 'product',
            productId: 'product-1',
            serviceId: '',
            productName: 'Product',
            quantityOrdered: 4,
            quantityReserved: 4,
            quantityShipped: 4,
            unitPrice: 10,
            lineAmount: 40,
            warehouseId: 'wh-1',
            warehouseName: 'Main',
            ledgerScope: LedgerScope.management,
          ),
        ],
        reservations: const [],
      );
      expect(shipped, OrderStatus.shipped);
      final closed = deriveOrderStatus(
        items: const [
          OrderItemLifecycleEntry(
            id: 'item-1',
            orderId: 'order-1',
            itemKind: 'product',
            productId: 'product-1',
            serviceId: '',
            productName: 'Product',
            quantityOrdered: 4,
            quantityReserved: 4,
            quantityShipped: 4,
            unitPrice: 10,
            lineAmount: 40,
            warehouseId: 'wh-1',
            warehouseName: 'Main',
            ledgerScope: LedgerScope.management,
          ),
        ],
        reservations: const [],
        fullyPaid: true,
      );
      expect(closed, OrderStatus.closed);
    });

    test('ledger scope does not mix during reservation', () {
      final allocations = reserveInventoryForOrderItems(
        orderItems: const [orderItem],
        inventoryBatches: batches,
        existingReservations: const [],
      );
      expect(
        allocations.every(
          (allocation) => allocation.ledgerScope == LedgerScope.management,
        ),
        isTrue,
      );
    });
  });
}
