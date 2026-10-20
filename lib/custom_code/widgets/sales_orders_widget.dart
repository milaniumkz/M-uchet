// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'index.dart';
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import '/utils/domain_entry_adapters.dart';
import '/utils/effective_company_support.dart';
import '/utils/order_lifecycle_service.dart';
import '/utils/order_lifecycle_support.dart';
import '/custom_code/widgets/company_reload_mixin.dart';
import '/utils/transaction_sync.dart';

class SalesOrdersWidget extends StatefulWidget {
  const SalesOrdersWidget({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<SalesOrdersWidget> createState() => _SalesOrdersWidgetState();
}

class _SalesOrdersWidgetState extends State<SalesOrdersWidget>
    with CompanyReloadMixin {
  final _firestore = FirebaseFirestore.instance;
  bool _loading = false;
  String _companyId = '';
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _reservations = [];
  List<Map<String, dynamic>> _productDocs = [];
  List<ClientEntryView> _clients = [];
  List<CatalogEntryView> _products = [];
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    markCompanyReloadBaseline();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = currentUser;
      if (user == null) {
        setState(() {
          _companyId = '';
          _orders = [];
          _reservations = [];
          _productDocs = [];
          _clients = [];
          _products = [];
          _loading = false;
        });
        return;
      }
      final companyId = resolveEffectiveCompanyId(
        userData: currentUserDocument?.snapshotData,
        fallbackUserId: currentUserUid,
      );
      final results = await Future.wait([
        _firestore
            .collection('customer_orders')
            .where('idCompany', isEqualTo: companyId)
            .getCached(),
        _firestore
            .collection('inventory_reservations')
            .where('idCompany', isEqualTo: companyId)
            .getCached(),
        _firestore
            .collection('clients')
            .where('idCompany', isEqualTo: companyId)
            .getCached(),
        _firestore
            .collection('nomenklatura')
            .where('idCompany', isEqualTo: companyId)
            .getCached(),
      ]);
      final ordersSnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final reservationsSnap =
          results[1] as QuerySnapshot<Map<String, dynamic>>;
      final clientsSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
      final productsSnap = results[3] as QuerySnapshot<Map<String, dynamic>>;
      final orders = ordersSnap.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList(growable: false)
        ..sort((a, b) {
          final ad = _millis(a['created_at'] ?? a['updated_at']);
          final bd = _millis(b['created_at'] ?? b['updated_at']);
          return bd.compareTo(ad);
        });
      final reservations = reservationsSnap.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList(growable: false);
      final clients = clientsSnap.docs
          .map((doc) => ClientEntryView.fromMap({'id': doc.id, ...doc.data()}))
          .toList(growable: false)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final productDocs = productsSnap.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
                'item_kind': 'product',
              })
          .toList(growable: false);
      final products = productDocs
          .map(CatalogEntryView.fromMap)
          .where((item) => item.isProduct)
          .toList(growable: false)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _companyId = companyId;
        _orders = orders;
        _reservations = reservations;
        _productDocs = productDocs;
        _clients = clients;
        _products = products;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading sales orders: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  int _millis(dynamic value) {
    if (value is Timestamp) return value.toDate().millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    return 0;
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_statusFilter == 'ALL') return _orders;
    return _orders
        .where((order) => (order['status'] ?? '').toString() == _statusFilter)
        .toList(growable: false);
  }

  int _countByStatus(String status) => _orders
      .where((order) => (order['status'] ?? '').toString() == status)
      .length;

  double _reservedQtyForOrder(String orderId) {
    return _reservations.fold<double>(0, (total, raw) {
      final reservation = InventoryReservationEntry.fromMap(raw);
      if (reservation.orderId != orderId) return total;
      return total + reservation.openReservedQty;
    });
  }

  Future<void> _applyLifecyclePlan(OrderLifecycleWritePlan plan) async {
    final batch = _firestore.batch();
    if (plan.orderData.isNotEmpty) {
      batch.set(plan.orderRef, plan.orderData);
    }
    for (final write in plan.orderItemWrites) {
      if (write.merge) {
        batch.set(write.reference, write.data, SetOptions(merge: true));
      } else {
        batch.set(write.reference, write.data);
      }
    }
    for (final write in plan.reservationWrites) {
      if (write.merge) {
        batch.set(write.reference, write.data, SetOptions(merge: true));
      } else {
        batch.set(write.reference, write.data);
      }
    }
    for (final write in plan.shipmentWrites) {
      batch.set(write.reference, write.data);
    }
    for (final write in plan.paymentWrites) {
      batch.set(write.reference, write.data);
    }
    for (final write in plan.orderUpdates) {
      if (write.merge) {
        batch.set(write.reference, write.data, SetOptions(merge: true));
      } else {
        batch.set(write.reference, write.data);
      }
    }
    await batch.commit();
    await _loadData();
  }

  Future<void> _reserveOrder(String orderId) async {
    try {
      final plan = await buildReserveOrderWritePlan(
        firestore: _firestore,
        companyId: _companyId,
        orderId: orderId,
      );
      await _applyLifecyclePlan(plan);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось зарезервировать: $e')),
      );
    }
  }

  Future<void> _createOrder() async {
    if (_products.isEmpty) return;
    final customerController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController();
    ClientEntryView? selectedClient =
        _clients.isNotEmpty ? _clients.first : null;
    Map<String, dynamic> selectedProductData = _productDocs.first;
    CatalogEntryView selectedProduct = CatalogEntryView.fromMap(selectedProductData);
    priceController.text = selectedProduct.effectivePrice.toStringAsFixed(0);

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Создать заказ'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<Map<String, dynamic>>(
                      initialValue: selectedProductData,
                      decoration: const InputDecoration(labelText: 'Товар'),
                      items: _productDocs
                          .map(
                            (product) => DropdownMenuItem<Map<String, dynamic>>(
                              value: product,
                              child: Text((product['name'] ?? '').toString()),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setLocalState(() {
                          selectedProductData = value;
                          selectedProduct = CatalogEntryView.fromMap(value);
                          priceController.text =
                              selectedProduct.effectivePrice.toStringAsFixed(0);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ClientEntryView?>(
                      initialValue: selectedClient,
                      decoration: const InputDecoration(labelText: 'Клиент'),
                      items: [
                        const DropdownMenuItem<ClientEntryView?>(
                          value: null,
                          child: Text('Без клиента'),
                        ),
                        ..._clients.map(
                          (client) => DropdownMenuItem<ClientEntryView?>(
                            value: client,
                            child: Text(client.displayLabel),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setLocalState(() => selectedClient = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: customerController,
                      decoration: const InputDecoration(
                        labelText: 'Комментарий',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyController,
                      decoration:
                          const InputDecoration(labelText: 'Количество'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'Цена'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Создать'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created != true) return;

    try {
      final qty = double.tryParse(qtyController.text.replaceAll(',', '.')) ?? 0;
      final price =
          double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0;
      if (qty <= 0 || price < 0) {
        throw const OrderLifecycleException('Некорректные количество или цена');
      }
      final plan = await buildCreateOrderWritePlan(
        firestore: _firestore,
        companyId: _companyId,
        customerId: selectedClient?.id ?? '',
        customerName: selectedClient?.name ?? '',
        ledgerScope: selectedProduct.ledgerScope,
        notes: customerController.text,
        items: [
          {
            'id': selectedProduct.id,
            'name': selectedProduct.name,
            'qty': qty,
            'sale_price': price,
            'warehouse_id':
                (selectedProductData['warehouse_id'] ?? selectedProductData['warehouse'] ?? '')
                    .toString(),
            'warehouse_name':
                (selectedProductData['warehouse_name'] ?? selectedProductData['warehouse'] ?? '')
                    .toString(),
          },
        ],
      );
      await _applyLifecyclePlan(plan);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось создать заказ: $e')),
      );
    }
  }

  Future<void> _releaseOrder(String orderId) async {
    try {
      final plan = await buildReleaseOrderReservationWritePlan(
        firestore: _firestore,
        companyId: _companyId,
        orderId: orderId,
      );
      await _applyLifecyclePlan(plan);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось снять резерв: $e')),
      );
    }
  }

  Future<void> _shipOrder(String orderId) async {
    try {
      final plan = await buildShipOrderWritePlan(
        firestore: _firestore,
        companyId: _companyId,
        orderId: orderId,
      );
      final batch = _firestore.batch();
      batch.set(plan.salePlan.saleRef, plan.salePlan.saleData);
      batch.set(plan.salePlan.transactionRef, plan.salePlan.transactionData);
      for (final write in plan.salePlan.entryWrites) {
        batch.set(write.reference, write.data);
      }
      for (final write in plan.salePlan.stockWrites) {
        batch.update(write.reference, write.data);
      }
      for (final write in plan.salePlan.salesItemWrites) {
        batch.set(write.reference, write.data);
      }
      for (final write in plan.salePlan.serviceExecutionWrites) {
        batch.set(write.reference, write.data);
      }
      for (final write in plan.salePlan.inventoryBatchWrites) {
        if (write.merge) {
          batch.set(write.reference, write.data, SetOptions(merge: true));
        } else {
          batch.set(write.reference, write.data);
        }
      }
      for (final write in plan.salePlan.cogsWrites) {
        if (write.merge) {
          batch.set(write.reference, write.data, SetOptions(merge: true));
        } else {
          batch.set(write.reference, write.data);
        }
      }
      for (final write in plan.salePlan.cogsEntryWrites) {
        batch.set(write.reference, write.data);
      }
      for (final write in plan.salePlan.batchConsumptionWrites) {
        batch.set(write.reference, write.data);
      }
      for (final write in plan.salePlan.debtWrites) {
        if (write.merge) {
          batch.set(write.reference, write.data, SetOptions(merge: true));
        } else {
          batch.set(write.reference, write.data);
        }
      }
      for (final write in plan.salePlan.orderWrites) {
        if (write.merge) {
          batch.set(write.reference, write.data, SetOptions(merge: true));
        } else {
          batch.set(write.reference, write.data);
        }
      }
      for (final write in plan.salePlan.orderItemWrites) {
        if (write.merge) {
          batch.set(write.reference, write.data, SetOptions(merge: true));
        } else {
          batch.set(write.reference, write.data);
        }
      }
      for (final write in plan.salePlan.shipmentWrites) {
        batch.set(write.reference, write.data);
      }
      for (final write in plan.salePlan.paymentWrites) {
        batch.set(write.reference, write.data);
      }
      for (final write in plan.salePlan.eventWrites) {
        batch.set(write.reference, write.data);
      }
      for (final write in plan.reservationWrites) {
        if (write.merge) {
          batch.set(write.reference, write.data, SetOptions(merge: true));
        } else {
          batch.set(write.reference, write.data);
        }
      }
      await batch.commit();
      await TransactionSync.recomputeAllForCompany(_companyId);
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отгрузить: $e')),
      );
    }
  }

  Widget _summaryCard(String label, String value, VoidCallback? onTap) {
    final selected = _statusFilter == value || (value == 'ALL' && _statusFilter == 'ALL');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? FlutterFlowTheme.of(context).primary.withValues(alpha: 0.08)
              : FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? FlutterFlowTheme.of(context).primary
                : FlutterFlowTheme.of(context).alternate,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: FlutterFlowTheme.of(context).bodyMedium),
            const SizedBox(height: 6),
            Text(
              value == 'ALL'
                  ? _orders.length.toString()
                  : _countByStatus(value).toString(),
              style: FlutterFlowTheme.of(context).headlineSmall,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveFrame(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _products.isEmpty ? null : _createOrder,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Создать заказ'),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 150,
                  child: _summaryCard(
                    'Все',
                    'ALL',
                    () => setState(() => _statusFilter = 'ALL'),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: _summaryCard(
                    'Новые',
                    OrderStatus.newOrder.storageValue,
                    () => setState(
                      () => _statusFilter = OrderStatus.newOrder.storageValue,
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: _summaryCard(
                    'В резерве',
                    OrderStatus.reserved.storageValue,
                    () => setState(
                      () => _statusFilter = OrderStatus.reserved.storageValue,
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: _summaryCard(
                    'Отгружены',
                    OrderStatus.shipped.storageValue,
                    () => setState(
                      () => _statusFilter = OrderStatus.shipped.storageValue,
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: _summaryCard(
                    'Закрыты',
                    OrderStatus.closed.storageValue,
                    () => setState(
                      () => _statusFilter = OrderStatus.closed.storageValue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ))
            else if (_filteredOrders.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: FlutterFlowTheme.of(context).alternate,
                  ),
                ),
                child: Text(
                  'Заказы не найдены',
                  style: FlutterFlowTheme.of(context).bodyLarge,
                ),
              )
            else
              Column(
                children: _filteredOrders.map((order) {
                  final status =
                      orderStatusFromValue(order['status']).storageValue;
                  final orderId = (order['id'] ?? '').toString();
                  final reservedQty = _reservedQtyForOrder(orderId);
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: FlutterFlowTheme.of(context).alternate,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                (order['order_number'] ?? orderId).toString(),
                                style: FlutterFlowTheme.of(context).titleMedium,
                              ),
                            ),
                            Chip(label: Text(status)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (order['customer_name'] ?? 'Без клиента').toString(),
                          style: FlutterFlowTheme.of(context).bodyLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Сумма: ${(order['total_amount'] ?? 0).toString()} | Резерв: ${reservedQty.toStringAsFixed(2)}',
                          style: FlutterFlowTheme.of(context).bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (status == OrderStatus.newOrder.storageValue)
                              ElevatedButton(
                                onPressed: () => _reserveOrder(orderId),
                                child: const Text('Резерв'),
                              ),
                            if (status == OrderStatus.reserved.storageValue)
                              ElevatedButton(
                                onPressed: () => _shipOrder(orderId),
                                child: const Text('Отгрузить'),
                              ),
                            if (status == OrderStatus.newOrder.storageValue)
                              ElevatedButton(
                                onPressed: () => _shipOrder(orderId),
                                child: const Text('Отгрузить'),
                              ),
                            if (status == OrderStatus.reserved.storageValue)
                              OutlinedButton(
                                onPressed: () => _releaseOrder(orderId),
                                child: const Text('Снять резерв'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }
}
