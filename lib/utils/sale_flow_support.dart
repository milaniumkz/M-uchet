import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/tranzaction_record.dart';
import '/backend/schema/util/firestore_util.dart';
import '/utils/accounting_entry_service.dart';
import '/utils/app_money_format.dart';
import '/utils/business_event_support.dart';
import '/utils/country_profile.dart';
import '/utils/debt_register_support.dart';
import '/utils/inventory_batch_support.dart';
import '/utils/inventory_costing_method.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_amount.dart';
import '/utils/money_wallet_support.dart';
import '/utils/money_wallet_types.dart';
import '/utils/order_lifecycle_support.dart';
import '/utils/service_accounting_support.dart';

class SaleFlowException implements Exception {
  const SaleFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<String> _resolveCompanyCurrencyForSale({
  required FirebaseFirestore firestore,
  required String companyId,
  required Map<String, dynamic>? accountData,
}) async {
  final accountCurrency = companyCurrencyFromData(
    accountData ?? const <String, dynamic>{},
    fallback: '',
  );
  if (accountCurrency.isNotEmpty) return accountCurrency;
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

class SaleFlowWritePlan {
  const SaleFlowWritePlan({
    required this.saleRef,
    required this.transactionRef,
    required this.saleData,
    required this.transactionData,
    required this.entryWrites,
    required this.salesItemWrites,
    required this.serviceExecutionWrites,
    required this.inventoryBatchWrites,
    required this.cogsWrites,
    required this.cogsEntryWrites,
    required this.batchConsumptionWrites,
    required this.debtWrites,
    required this.orderWrites,
    required this.orderItemWrites,
    required this.shipmentWrites,
    required this.paymentWrites,
    required this.eventWrites,
    required this.stockWrites,
    required this.cashRegisterPatch,
    required this.cogsTotal,
  });

  final DocumentReference saleRef;
  final DocumentReference transactionRef;
  final Map<String, dynamic> saleData;
  final Map<String, dynamic> transactionData;
  final List<SaleFlowDocWrite> entryWrites;
  final List<SaleFlowDocWrite> salesItemWrites;
  final List<SaleFlowDocWrite> serviceExecutionWrites;
  final List<SaleFlowDocWrite> inventoryBatchWrites;
  final List<SaleFlowDocWrite> cogsWrites;
  final List<SaleFlowDocWrite> cogsEntryWrites;
  final List<SaleFlowDocWrite> batchConsumptionWrites;
  final List<SaleFlowDocWrite> debtWrites;
  final List<SaleFlowDocWrite> orderWrites;
  final List<SaleFlowDocWrite> orderItemWrites;
  final List<SaleFlowDocWrite> shipmentWrites;
  final List<SaleFlowDocWrite> paymentWrites;
  final List<SaleFlowDocWrite> eventWrites;
  final List<SaleFlowDocWrite> stockWrites;
  final Map<String, dynamic> cashRegisterPatch;
  final double cogsTotal;
}

class SaleFlowDocWrite {
  const SaleFlowDocWrite(
    this.reference,
    this.data, {
    this.merge = false,
  });

  final DocumentReference reference;
  final Map<String, dynamic> data;
  final bool merge;
}

class CashRegisterIncassationWritePlan {
  const CashRegisterIncassationWritePlan({
    required this.incassationRef,
    required this.transactionRef,
    required this.incassationData,
    required this.transactionData,
    required this.entryWrites,
    required this.cashRegisterPatch,
  });

  final DocumentReference incassationRef;
  final DocumentReference transactionRef;
  final Map<String, dynamic> incassationData;
  final Map<String, dynamic> transactionData;
  final List<SaleFlowDocWrite> entryWrites;
  final Map<String, dynamic> cashRegisterPatch;
}

Future<SaleFlowWritePlan> buildCashSaleWritePlan({
  required FirebaseFirestore firestore,
  required String companyId,
  required String cashierId,
  required String cashierName,
  required String shopId,
  required String shopName,
  required String cashRegisterId,
  required String cashRegisterName,
  required String clientId,
  required String clientName,
  required double amount,
  required double discount,
  required String paymentMethod,
  required String typeUchet,
  required LedgerScope ledgerScope,
  required List<Map<String, dynamic>> cart,
  required DocumentReference? accountReference,
  required String accountTitle,
  required double nextCashSales,
  required double nextCardSales,
  required double nextTransactions,
  double? exchangeRateToCompany,
  DateTime? exchangeRateDate,
  String exchangeRateSource = 'manual_sale_payment',
  String? existingOrderId,
}) async {
  final trimmedCompanyId = companyId.trim();
  if (trimmedCompanyId.isEmpty) {
    throw const SaleFlowException('Company id is required');
  }
  if (cart.isEmpty) {
    throw const SaleFlowException('Cart is empty');
  }

  final saleRef = firestore.collection('sales').doc();
  final transactionRef = firestore.collection('tranzaction').doc();
  final hasExistingOrder =
      existingOrderId != null && existingOrderId.trim().isNotEmpty;
  final accountWallet = await ensureWalletForAccountReference(
    firestore: firestore,
    accountRef: accountReference,
    fallbackTitle: accountTitle,
  );
  final accountData = await _loadAccountData(accountReference);
  final companyCurrency = await _resolveCompanyCurrencyForSale(
    firestore: firestore,
    companyId: trimmedCompanyId,
    accountData: accountData,
  );
  final cashRegisterWallet = cashRegisterName.trim().isEmpty
      ? null
      : await ensureWalletForCashRegister(
          firestore: firestore,
          registerData: {
            'idCompany': trimmedCompanyId,
            'cash_register_name': cashRegisterName.trim(),
            'ledger_scope': ledgerScope.storageValue,
            'ending_cash': paymentMethod == 'cash' ? amount : 0.0,
            'opening_cash': 0.0,
          },
        );

  final salesItemWrites = <SaleFlowDocWrite>[];
  final serviceExecutionWrites = <SaleFlowDocWrite>[];
  final inventoryBatchWrites = <SaleFlowDocWrite>[];
  final cogsWrites = <SaleFlowDocWrite>[];
  final cogsEntryWrites = <SaleFlowDocWrite>[];
  final batchConsumptionWrites = <SaleFlowDocWrite>[];
  final debtWrites = <SaleFlowDocWrite>[];
  final orderWrites = <SaleFlowDocWrite>[];
  final orderItemWrites = <SaleFlowDocWrite>[];
  final shipmentWrites = <SaleFlowDocWrite>[];
  final paymentWrites = <SaleFlowDocWrite>[];
  final eventWrites = <SaleFlowDocWrite>[];
  final stockWrites = <SaleFlowDocWrite>[];
  double cogsTotal = 0.0;
  final isReceivableSale = paymentMethod.trim().toLowerCase() == 'debt';
  String? receivableDebtId;
  final orderRef = hasExistingOrder
      ? firestore.collection('customer_orders').doc(existingOrderId.trim())
      : firestore.collection('customer_orders').doc();
  final shipmentRef = firestore.collection('shipments').doc();
  final orderPaymentRef = firestore.collection('order_payments').doc();

  final saleData = <String, dynamic>{
    'idCompany': trimmedCompanyId,
    ...ledgerScopeFields(
      ledgerScope: ledgerScope,
      legacyTypeUchet: typeUchet,
    ),
    'cashier_id': cashierId.trim(),
    'cashier_name': cashierName.trim(),
    'shop_id': shopId.trim(),
    'shop_name': shopName.trim(),
    'cash_register_id': cashRegisterId.trim(),
    'cash_register_name': cashRegisterName.trim(),
    'client_id': clientId.trim(),
    'client_name': clientName.trim(),
    'amount': amount,
    'company_currency': companyCurrency,
    'companyCurrency': companyCurrency,
    'discount': discount,
    'payment_method': paymentMethod,
    'transaction_id': transactionRef.id,
    'order_id': orderRef.id,
    'shipment_id': shipmentRef.id,
    'items_count': cart.length,
    'cogs_total': 0.0,
    'created_at': FieldValue.serverTimestamp(),
  };

  final baseTransactionData = <String, dynamic>{
    ...createTranzactionRecordData(
      type: 'income',
      typeUchet: typeUchet,
      ledgerScope: ledgerScope.storageValue,
      kat: 'Продажа',
      text: isReceivableSale
          ? 'Продажа (в долг)'
          : 'Продажа (${paymentMethod == 'cash' ? 'наличные' : 'карта'})',
      summa: amount,
      nds: false,
      summaNds: 0,
      idCompany: trimmedCompanyId,
      schetId: isReceivableSale ? null : accountReference,
      schetTitle: isReceivableSale ? 'Дебиторка' : accountTitle,
      walletId: isReceivableSale ? null : accountWallet?.reference.id,
      walletName: isReceivableSale ? null : accountWallet?.name,
      walletType: isReceivableSale ? null : accountWallet?.type,
      fromWalletId:
          paymentMethod == 'cash' ? cashRegisterWallet?.reference.id : null,
      fromWalletName: paymentMethod == 'cash' ? cashRegisterWallet?.name : null,
      status: 'posted',
    ),
    if (!isReceivableSale)
      ...mapToFirestore(
        transactionMoneyFieldsForAccountData(
          amountOriginal: amount,
          accountData: accountData,
          exchangeRateToCompany: exchangeRateToCompany,
          exchangeRateDate: exchangeRateDate,
          exchangeRateSource: exchangeRateSource,
        ),
      ),
    ...mapToFirestore({
      'date': FieldValue.serverTimestamp(),
      'sale_id': saleRef.id,
      'order_id': orderRef.id,
      'shipment_id': shipmentRef.id,
      'order_payment_id': isReceivableSale ? null : orderPaymentRef.id,
      'source': 'sales.cash_mode',
      'payment_method': paymentMethod,
      'cashier_id': cashierId.trim(),
      'cashier_name': cashierName.trim(),
      'shop_id': shopId.trim(),
      'shop_name': shopName.trim(),
      'client_id': clientId.trim(),
      'client_name': clientName.trim(),
    }),
  };
  if (isReceivableSale) {
    receivableDebtId = debtDocIdForSource(
      type: DebtType.ar,
      sourceType: 'sale',
      sourceDocumentId: saleRef.id,
    );
    baseTransactionData['receivable_debt_id'] = receivableDebtId;
    baseTransactionData['receivableDebtId'] = receivableDebtId;
  }
  final entryBuild = buildEntryPayloadsForTransaction(
    firestore: firestore,
    transactionRef: transactionRef,
    transactionData: baseTransactionData,
  );
  final transactionData = <String, dynamic>{
    ...baseTransactionData,
    'entry_ids': entryBuild.entryIds,
    'entries_generated_at': FieldValue.serverTimestamp(),
  };
  final entryWrites = entryBuild.writes
      .map((write) => SaleFlowDocWrite(write.key, write.value))
      .toList();
  if (isReceivableSale) {
    debtWrites.add(
      SaleFlowDocWrite(
        firestore.collection('debt_register').doc(receivableDebtId),
        buildDebtRecordPayload(
          idCompany: trimmedCompanyId,
          type: DebtType.ar,
          counterpartyId: clientId,
          counterpartyName: clientName,
          sourceDocumentId: saleRef.id,
          sourceType: 'sale',
          totalAmount: amount,
          remainingAmount: amount,
          ledgerScope: ledgerScope,
          createdAt: DateTime.now(),
        ),
      ),
    );
  }

  for (final item in cart) {
    final kind = (item['item_kind'] ?? 'product').toString();
    final qty = _toNum(item['qty']);
    final price = _toNum(item['sale_price'] ?? item['price']);
    if (qty <= 0) {
      throw const SaleFlowException('Cart item quantity must be positive');
    }
    double itemCost = 0.0;
    int itemBatchCount = 0;
    var appliedCostingMethod = InventoryCostingMethod.fifo;
    double appliedUnitCost = 0.0;
    final saleItemRef = firestore.collection('sales_items').doc();
    final existingOrderItemId = (item['order_item_id'] ?? '').toString().trim();
    final hasExistingOrderItem =
        hasExistingOrder && existingOrderItemId.isNotEmpty;
    final orderItemRef = hasExistingOrderItem
        ? firestore.collection('customer_order_items').doc(existingOrderItemId)
        : firestore.collection('customer_order_items').doc();
    if (kind == 'product') {
      final productId = item['id'].toString();
      final productName = (item['name'] ?? '').toString();
      final warehouseId =
          (item['warehouse_id'] ?? item['warehouse'] ?? '').toString().trim();
      final warehouseName =
          (item['warehouse_name'] ?? item['warehouse'] ?? '').toString().trim();
      final stock = _toNum(item['stock']);
      final purchasePrice = _toNum(item['purchase_price']);
      if (stock + 1e-9 < qty) {
        throw SaleFlowException(
          'Insufficient stock for ${item['name'] ?? 'product'}',
        );
      }
      final batchSnap = await firestore
          .collection('inventory_batches')
          .where('idCompany', isEqualTo: trimmedCompanyId)
          .where('product_id', isEqualTo: productId)
          .get();
      final relevantBatches = batchSnap.docs
          .map((doc) => InventoryBatchEntry.fromMap({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
      final syntheticBatchRef = firestore.collection('inventory_batches').doc();
      final preparedBatches = prepareInventoryBatchesForSale(
        companyId: trimmedCompanyId,
        productId: productId,
        productName: productName,
        warehouseId: warehouseId,
        warehouseName: warehouseName,
        ledgerScope: ledgerScope,
        existingBatches: relevantBatches,
        stockQty: stock,
        unitCost: purchasePrice,
        syntheticBatchId: syntheticBatchRef.id,
      );

      final costingMethod = resolveInventoryCostingMethod(productData: item);
      final costing = consumeInventoryBatches(
        batches: preparedBatches.batches,
        ledgerScope: ledgerScope,
        requestedQty: qty,
        costingMethod: costingMethod,
      );
      appliedCostingMethod = costingMethod;
      appliedUnitCost = costing.unitCostApplied;
      itemCost = costing.totalCost;
      cogsTotal += itemCost;

      itemBatchCount = costing.consumptions.length;

      for (final batch in costing.updatedBatches) {
        final isSynthetic = preparedBatches.syntheticBatchId == batch.id;
        if (isSynthetic) {
          inventoryBatchWrites.add(
            SaleFlowDocWrite(
              syntheticBatchRef,
              <String, dynamic>{
                ...?preparedBatches.syntheticBatchPayload,
                'qty_initial': batch.qtyInitial,
                'qty_remaining': batch.qtyRemaining,
                'total_cost': batch.qtyRemaining * batch.unitCost,
                'status': batch.qtyRemaining <= 0 ? 'DEPLETED' : 'ACTIVE',
                'is_active': batch.qtyRemaining > 0,
              },
            ),
          );
        } else {
          inventoryBatchWrites.add(
            SaleFlowDocWrite(
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
      }

      for (final consumption in costing.consumptions) {
        cogsWrites.add(
          SaleFlowDocWrite(
            firestore.collection('sale_item_cogs').doc(),
            buildSaleItemCogsPayload(
              companyId: trimmedCompanyId,
              saleId: saleRef.id,
              saleItemId: saleItemRef.id,
              productId: productId,
              productName: productName,
              warehouseId: warehouseId,
              warehouseName: warehouseName,
              ledgerScope: ledgerScope,
              consumption: consumption,
              costingMethod: costing.costingMethod,
              unitCostApplied: costing.unitCostApplied,
            ),
          ),
        );
        cogsEntryWrites.add(
          SaleFlowDocWrite(
            firestore.collection('cogs_register').doc(),
            buildCogsEntryPayload(
              companyId: trimmedCompanyId,
              saleId: saleRef.id,
              saleItemId: saleItemRef.id,
              productId: productId,
              productName: productName,
              warehouseId: warehouseId,
              warehouseName: warehouseName,
              ledgerScope: ledgerScope,
              consumption: consumption,
              costingMethod: costing.costingMethod,
              unitCostApplied: costing.unitCostApplied,
            ),
          ),
        );
        if (consumption.batchId.isNotEmpty) {
          batchConsumptionWrites.add(
            SaleFlowDocWrite(
              firestore.collection('batch_consumptions').doc(),
              buildBatchConsumptionPayload(
                companyId: trimmedCompanyId,
                saleId: saleRef.id,
                saleItemId: saleItemRef.id,
                ledgerScope: ledgerScope,
                consumption: consumption,
              ),
            ),
          );
        }
        eventWrites.add(
          SaleFlowDocWrite(
            firestore.collection('business_events').doc(),
            buildBusinessEventPayload(
              companyId: trimmedCompanyId,
              type: BusinessEventType.inventoryMoved,
              ledgerScope: ledgerScope,
              aggregateId: saleRef.id,
              saleId: saleRef.id,
              saleItemId: saleItemRef.id,
              productId: productId,
              warehouseId: warehouseId,
              warehouseName: warehouseName,
              quantity: consumption.qty,
              cost: consumption.totalCost,
            ),
          ),
        );
      }

      stockWrites.add(
        SaleFlowDocWrite(
          firestore.collection('nomenklatura').doc(productId),
          <String, dynamic>{
            'stock': costing.remainingQty,
            'stock_value': costing.remainingValue,
            'purchase_price': costing.remainingQty <= 0
                ? (item['purchase_price'] ?? 0)
                : costing.remainingValue / costing.remainingQty,
            'inventory_costing_method': costingMethod.storageValue,
            'costing_method': costingMethod.storageValue,
            'updated_at': FieldValue.serverTimestamp(),
          },
          merge: true,
        ),
      );
    } else if (kind == 'service') {
      final serviceId = item['id'].toString();
      final serviceName = (item['name'] ?? '').toString();
      final serviceCategory = (item['category'] ?? '').toString();
      final costModelSnap = await firestore
          .collection('service_cost_models')
          .doc(serviceId)
          .get();
      final costModel = ServiceCostModelView.fromMaps(
        serviceId: serviceId,
        serviceData: item,
        costModelData: costModelSnap.exists
            ? <String, dynamic>{
                'id': costModelSnap.id,
                ...costModelSnap.data()!
              }
            : null,
      );
      if (!costModel.ledgerScope.matches(ledgerScope)) {
        throw SaleFlowException(
          'Service ledger scope mismatch for ${item['name'] ?? 'service'}',
        );
      }
      final execution = calculateServiceExecution(
        costModel: costModel,
        quantity: qty,
        unitPrice: price,
      );
      itemCost = execution.costAmount;
      cogsTotal += itemCost;
      appliedUnitCost = execution.unitCost;
      cogsWrites.add(
        SaleFlowDocWrite(
          firestore.collection('sale_item_cogs').doc(),
          buildServiceSaleCogsPayload(
            companyId: trimmedCompanyId,
            saleId: saleRef.id,
            saleItemId: saleItemRef.id,
            serviceId: serviceId,
            serviceName: serviceName,
            ledgerScope: ledgerScope,
            execution: execution,
          ),
        ),
      );
      cogsEntryWrites.add(
        SaleFlowDocWrite(
          firestore.collection('cogs_register').doc(),
          buildServiceCogsEntryPayload(
            companyId: trimmedCompanyId,
            saleId: saleRef.id,
            saleItemId: saleItemRef.id,
            serviceId: serviceId,
            serviceName: serviceName,
            ledgerScope: ledgerScope,
            execution: execution,
          ),
        ),
      );
      serviceExecutionWrites.add(
        SaleFlowDocWrite(
          firestore.collection('service_executions').doc(),
          buildServiceExecutionPayload(
            companyId: trimmedCompanyId,
            saleId: saleRef.id,
            saleItemId: saleItemRef.id,
            transactionId: transactionRef.id,
            serviceId: serviceId,
            serviceName: serviceName,
            serviceCategory: serviceCategory,
            customerId: clientId,
            customerName: clientName,
            shopId: shopId,
            shopName: shopName,
            cashRegisterId: cashRegisterId,
            cashRegisterName: cashRegisterName,
            ledgerScope: ledgerScope,
            execution: execution,
            status: 'COMPLETED',
          ),
        ),
      );
      eventWrites.add(
        SaleFlowDocWrite(
          firestore.collection('business_events').doc(),
          buildBusinessEventPayload(
            companyId: trimmedCompanyId,
            type: BusinessEventType.servicePerformed,
            ledgerScope: ledgerScope,
            aggregateId: saleRef.id,
            saleId: saleRef.id,
            saleItemId: saleItemRef.id,
            serviceId: serviceId,
            transactionId: transactionRef.id,
            revenue: price * qty,
            cost: itemCost,
            quantity: qty,
          ),
        ),
      );
    }

    salesItemWrites.add(
      SaleFlowDocWrite(
        saleItemRef,
        <String, dynamic>{
          'idCompany': trimmedCompanyId,
          ...ledgerScopeFields(
            ledgerScope: ledgerScope,
            legacyTypeUchet: typeUchet,
          ),
          'sale_id': saleRef.id,
          'order_id': orderRef.id,
          'order_item_id': orderItemRef.id,
          'shipment_id': shipmentRef.id,
          'transaction_id': transactionRef.id,
          'item_type': kind,
          'product_id': kind == 'product' ? item['id'] : null,
          'service_id': kind == 'service' ? item['id'] : null,
          'warehouse_id': kind == 'product'
              ? (item['warehouse_id'] ?? item['warehouse'])
              : null,
          'warehouse_name': kind == 'product'
              ? (item['warehouse_name'] ?? item['warehouse'])
              : null,
          'product_name': kind == 'product' ? item['name'] : null,
          'service_name': kind == 'service' ? item['name'] : null,
          'name': (item['name'] ?? '').toString(),
          'qty': qty,
          'amount': price * qty,
          'cost': itemCost,
          'cogs_amount': itemCost,
          'costing_method': appliedCostingMethod.storageValue,
          'unit_cost_applied': appliedUnitCost,
          'service_costing_type': kind == 'service'
              ? serviceCostingTypeFromValue(
                      serviceString(item['costing_type']).isEmpty
                          ? serviceString(item['service_costing_type'])
                          : serviceString(item['costing_type']))
                  .storageValue
              : null,
          'batch_count': kind == 'product' ? itemBatchCount : 0,
          'created_at': FieldValue.serverTimestamp(),
        },
      ),
    );
    orderItemWrites.add(
      SaleFlowDocWrite(
        orderItemRef,
        hasExistingOrderItem
            ? <String, dynamic>{
                'quantity_reserved':
                    (_toNum(item['existing_quantity_reserved']) - qty)
                        .clamp(0, double.infinity),
                'quantity_shipped':
                    _toNum(item['existing_quantity_shipped']) + qty,
                'updated_at': FieldValue.serverTimestamp(),
              }
            : buildOrderItemPayload(
                companyId: trimmedCompanyId,
                orderId: orderRef.id,
                itemKind: kind,
                productId: kind == 'product' ? item['id'].toString() : '',
                serviceId: kind == 'service' ? item['id'].toString() : '',
                productName: (item['name'] ?? '').toString(),
                warehouseId: kind == 'product'
                    ? (item['warehouse_id'] ?? item['warehouse'] ?? '')
                        .toString()
                    : '',
                warehouseName: kind == 'product'
                    ? (item['warehouse_name'] ?? item['warehouse'] ?? '')
                        .toString()
                    : '',
                ledgerScope: ledgerScope,
                quantityOrdered: qty,
                quantityReserved: 0,
                quantityShipped: qty,
                unitPrice: price,
              ),
        merge: hasExistingOrderItem,
      ),
    );
  }

  saleData['cogs_total'] = cogsTotal;
  final totalQty = cart.fold<double>(
    0,
    (total, item) => total + _toNum(item['qty']),
  );
  final finalOrderStatus =
      isReceivableSale ? OrderStatus.shipped : OrderStatus.closed;
  orderWrites.add(
    SaleFlowDocWrite(
      orderRef,
      hasExistingOrder
          ? (<String, dynamic>{
              'status': finalOrderStatus.storageValue,
              'shipped_at': FieldValue.serverTimestamp(),
              'closed_at':
                  isReceivableSale ? null : FieldValue.serverTimestamp(),
              'updated_at': FieldValue.serverTimestamp(),
            }..removeWhere((key, value) => value == null))
          : buildCustomerOrderPayload(
              companyId: trimmedCompanyId,
              orderNumber: orderRef.id,
              customerId: clientId,
              customerName: clientName,
              warehouseId: cart
                  .map((item) =>
                      (item['warehouse_id'] ?? item['warehouse'] ?? '')
                          .toString())
                  .firstWhere((value) => value.trim().isNotEmpty,
                      orElse: () => ''),
              warehouseName: cart
                  .map((item) =>
                      (item['warehouse_name'] ?? item['warehouse'] ?? '')
                          .toString())
                  .firstWhere((value) => value.trim().isNotEmpty,
                      orElse: () => ''),
              ledgerScope: ledgerScope,
              status: finalOrderStatus,
              totalAmount: amount,
              currency: companyCurrency,
              shippedAt: DateTime.now(),
              closedAt: isReceivableSale ? null : DateTime.now(),
            ),
      merge: hasExistingOrder,
    ),
  );
  shipmentWrites.add(
    SaleFlowDocWrite(
      shipmentRef,
      buildShipmentPayload(
        companyId: trimmedCompanyId,
        orderId: orderRef.id,
        saleId: saleRef.id,
        ledgerScope: ledgerScope,
        warehouseId: cart
            .map((item) =>
                (item['warehouse_id'] ?? item['warehouse'] ?? '').toString())
            .firstWhere((value) => value.trim().isNotEmpty, orElse: () => ''),
        warehouseName: cart
            .map((item) =>
                (item['warehouse_name'] ?? item['warehouse'] ?? '').toString())
            .firstWhere((value) => value.trim().isNotEmpty, orElse: () => ''),
        totalAmount: amount,
        quantity: totalQty,
      ),
    ),
  );
  eventWrites.add(
    SaleFlowDocWrite(
      firestore.collection('business_events').doc(),
      buildBusinessEventPayload(
        companyId: trimmedCompanyId,
        type: BusinessEventType.saleCreated,
        ledgerScope: ledgerScope,
        aggregateId: saleRef.id,
        saleId: saleRef.id,
        transactionId: transactionRef.id,
        warehouseId: cart
            .map((item) =>
                (item['warehouse_id'] ?? item['warehouse'] ?? '').toString())
            .firstWhere((value) => value.trim().isNotEmpty, orElse: () => ''),
        warehouseName: cart
            .map((item) =>
                (item['warehouse_name'] ?? item['warehouse'] ?? '').toString())
            .firstWhere((value) => value.trim().isNotEmpty, orElse: () => ''),
        revenue: amount,
        cost: cogsTotal,
        quantity: totalQty,
        paymentMethod: paymentMethod,
      ),
    ),
  );
  if (!isReceivableSale) {
    paymentWrites.add(
      SaleFlowDocWrite(
        orderPaymentRef,
        buildOrderPaymentPayload(
          companyId: trimmedCompanyId,
          orderId: orderRef.id,
          transactionId: transactionRef.id,
          ledgerScope: ledgerScope,
          amount: amount,
          paymentMethod: paymentMethod,
        ),
      ),
    );
    eventWrites.add(
      SaleFlowDocWrite(
        firestore.collection('business_events').doc(),
        buildBusinessEventPayload(
          companyId: trimmedCompanyId,
          type: BusinessEventType.paymentReceived,
          ledgerScope: ledgerScope,
          aggregateId: saleRef.id,
          saleId: saleRef.id,
          transactionId: transactionRef.id,
          revenue: amount,
          paymentMethod: paymentMethod,
        ),
      ),
    );
  }

  return SaleFlowWritePlan(
    saleRef: saleRef,
    transactionRef: transactionRef,
    saleData: saleData,
    transactionData: transactionData,
    entryWrites: entryWrites,
    salesItemWrites: salesItemWrites,
    serviceExecutionWrites: serviceExecutionWrites,
    inventoryBatchWrites: inventoryBatchWrites,
    cogsWrites: cogsWrites,
    cogsEntryWrites: cogsEntryWrites,
    batchConsumptionWrites: batchConsumptionWrites,
    debtWrites: debtWrites,
    orderWrites: orderWrites,
    orderItemWrites: orderItemWrites,
    shipmentWrites: shipmentWrites,
    paymentWrites: paymentWrites,
    eventWrites: eventWrites,
    stockWrites: stockWrites,
    cashRegisterPatch: <String, dynamic>{
      'cash_sales': nextCashSales,
      'card_sales': nextCardSales,
      'transactions': nextTransactions,
      'updated_at': FieldValue.serverTimestamp(),
    },
    cogsTotal: cogsTotal,
  );
}

double _toNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

Future<Map<String, dynamic>?> _loadAccountData(DocumentReference? ref) async {
  if (ref == null) return null;
  final snap = await ref.get();
  if (!snap.exists || snap.data() is! Map) return null;
  return Map<String, dynamic>.from(snap.data() as Map);
}

Future<CashRegisterIncassationWritePlan> buildCashRegisterIncassationWritePlan({
  required FirebaseFirestore firestore,
  required String companyId,
  required String shiftId,
  required String cashRegisterName,
  required String cashierName,
  required String note,
  required double amount,
  required DocumentReference accountReference,
  required String accountTitle,
  required DateTime operationDate,
  required String typeUchet,
  required LedgerScope ledgerScope,
  required double nextIncassationTotal,
}) async {
  final trimmedCompanyId = companyId.trim();
  final trimmedShiftId = shiftId.trim();
  final trimmedRegisterName = cashRegisterName.trim();
  final trimmedCashierName = cashierName.trim();
  final trimmedNote = note.trim();
  if (trimmedCompanyId.isEmpty) {
    throw const SaleFlowException('Company id is required');
  }
  if (trimmedShiftId.isEmpty) {
    throw const SaleFlowException('Cash register shift id is required');
  }
  if (amount <= 0) {
    throw const SaleFlowException('Incassation amount must be positive');
  }
  if (trimmedCashierName.isEmpty) {
    throw const SaleFlowException('Cashier name is required');
  }
  if (trimmedRegisterName.isEmpty) {
    throw const SaleFlowException('Cash register name is required');
  }
  if (trimmedNote.isEmpty) {
    throw const SaleFlowException('Incassation note is required');
  }

  final incassationRef =
      firestore.collection('cash_register_incassations').doc();
  final transactionRef = firestore.collection('tranzaction').doc();
  final accountWallet = await ensureWalletForAccountReference(
    firestore: firestore,
    accountRef: accountReference,
    fallbackTitle: accountTitle,
  );
  final accountData = await _loadAccountData(accountReference);
  final cashRegisterWallet = await ensureWalletForCashRegister(
    firestore: firestore,
    registerData: {
      'id': trimmedShiftId,
      'idCompany': trimmedCompanyId,
      'cash_register_name': trimmedRegisterName,
      'ledger_scope': ledgerScope.storageValue,
      'ending_cash': nextIncassationTotal,
      'opening_cash': 0.0,
    },
  );

  final incassationData = <String, dynamic>{
    'idCompany': trimmedCompanyId,
    ...ledgerScopeFields(
      ledgerScope: ledgerScope,
      legacyTypeUchet: typeUchet,
    ),
    'cash_register_shift_id': trimmedShiftId,
    'cash_register_name': trimmedRegisterName,
    'cashier_name': trimmedCashierName,
    'amount': amount,
    'schetId': accountReference,
    'schetTitle': accountTitle,
    ...walletFields(
      walletId: cashRegisterWallet.reference.id,
      walletName: cashRegisterWallet.name,
      walletType: WalletType.cashbox,
      ledgerScope: ledgerScope,
    ),
    ...transferWalletFields(
      fromWalletId: cashRegisterWallet.reference.id,
      fromWalletName: cashRegisterWallet.name,
      toWalletId: accountWallet?.reference.id ?? '',
      toWalletName: accountWallet?.name ?? accountTitle,
    ),
    'date': Timestamp.fromDate(operationDate),
    'note': trimmedNote,
    'transaction_id': transactionRef.id,
    'created_at': FieldValue.serverTimestamp(),
  };

  final baseTransactionData = <String, dynamic>{
    ...createTranzactionRecordData(
      type: 'income',
      typeUchet: normalizeLegacyTypeUchet(typeUchet),
      ledgerScope: ledgerScope.storageValue,
      kat: 'Инкассация кассы',
      text: 'Инкассация кассы $trimmedRegisterName. $trimmedNote',
      summa: amount,
      nds: false,
      summaNds: 0,
      idCompany: trimmedCompanyId,
      schetId: accountReference,
      schetTitle: accountTitle,
      walletId: accountWallet?.reference.id,
      walletName: accountWallet?.name,
      walletType: accountWallet?.type,
      fromWalletId: cashRegisterWallet.reference.id,
      fromWalletName: cashRegisterWallet.name,
      toWalletId: accountWallet?.reference.id,
      toWalletName: accountWallet?.name,
      date: operationDate,
      counterparty: trimmedCashierName,
      status: 'posted',
    ),
    ...mapToFirestore(
      transactionMoneyFieldsForAccountData(
        amountOriginal: amount,
        accountData: accountData,
        exchangeRateDate: operationDate,
      ),
    ),
    ...mapToFirestore({
      'created_at': FieldValue.serverTimestamp(),
      'source': 'sales.cash_register_incassation',
      'cash_register_shift_id': trimmedShiftId,
      'cash_register_name': trimmedRegisterName,
      'cashier_name': trimmedCashierName,
      'incassation_id': incassationRef.id,
    }),
  };
  final entryBuild = buildEntryPayloadsForTransaction(
    firestore: firestore,
    transactionRef: transactionRef,
    transactionData: baseTransactionData,
  );
  final transactionData = <String, dynamic>{
    ...baseTransactionData,
    'entry_ids': entryBuild.entryIds,
    'entries_generated_at': FieldValue.serverTimestamp(),
  };
  final entryWrites = entryBuild.writes
      .map((write) => SaleFlowDocWrite(write.key, write.value))
      .toList();

  return CashRegisterIncassationWritePlan(
    incassationRef: incassationRef,
    transactionRef: transactionRef,
    incassationData: incassationData,
    transactionData: transactionData,
    entryWrites: entryWrites,
    cashRegisterPatch: <String, dynamic>{
      'incassation_total': nextIncassationTotal,
      'updated_at': FieldValue.serverTimestamp(),
    },
  );
}
