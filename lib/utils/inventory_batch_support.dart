import 'package:cloud_firestore/cloud_firestore.dart';

import '/utils/inventory_costing_method.dart';
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

class InventoryBatchException implements Exception {
  const InventoryBatchException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InventoryBatchEntry {
  const InventoryBatchEntry({
    required this.id,
    required this.companyId,
    required this.productId,
    required this.productName,
    required this.warehouseId,
    required this.warehouseName,
    required this.ledgerScope,
    required this.qtyInitial,
    required this.qtyRemaining,
    required this.unitCost,
    this.totalCost = 0,
    required this.createdAt,
    this.receivedAt,
    this.sourceDocumentId = '',
    this.sourceType = '',
    this.isActive = true,
    this.status = 'ACTIVE',
    required this.raw,
  });

  final String id;
  final String companyId;
  final String productId;
  final String productName;
  final String warehouseId;
  final String warehouseName;
  final LedgerScope ledgerScope;
  final double qtyInitial;
  final double qtyRemaining;
  final double unitCost;
  final double totalCost;
  final DateTime? createdAt;
  final DateTime? receivedAt;
  final String sourceDocumentId;
  final String sourceType;
  final bool isActive;
  final String status;
  final Map<String, dynamic> raw;

  InventoryBatchEntry copyWith({
    String? id,
    String? companyId,
    String? productId,
    String? productName,
    String? warehouseId,
    String? warehouseName,
    LedgerScope? ledgerScope,
    double? qtyInitial,
    double? qtyRemaining,
    double? unitCost,
    double? totalCost,
    DateTime? createdAt,
    DateTime? receivedAt,
    String? sourceDocumentId,
    String? sourceType,
    bool? isActive,
    String? status,
    Map<String, dynamic>? raw,
  }) {
    return InventoryBatchEntry(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      warehouseId: warehouseId ?? this.warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
      ledgerScope: ledgerScope ?? this.ledgerScope,
      qtyInitial: qtyInitial ?? this.qtyInitial,
      qtyRemaining: qtyRemaining ?? this.qtyRemaining,
      unitCost: unitCost ?? this.unitCost,
      totalCost: totalCost ?? this.totalCost,
      createdAt: createdAt ?? this.createdAt,
      receivedAt: receivedAt ?? this.receivedAt,
      sourceDocumentId: sourceDocumentId ?? this.sourceDocumentId,
      sourceType: sourceType ?? this.sourceType,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      raw: raw ?? this.raw,
    );
  }

  factory InventoryBatchEntry.fromMap(Map<String, dynamic> data) {
    final qtyInitial = _num(data['qty_initial'] ?? data['qtyInitial']);
    final qtyRemaining = _num(data['qty_remaining'] ?? data['qtyRemaining']);
    final unitCost = _num(data['unit_cost'] ?? data['unitCost']);
    return InventoryBatchEntry(
      id: _string(data['id']),
      companyId: _string(data['idCompany']),
      productId: _string(data['product_id']),
      productName: _string(data['product_name']),
      warehouseId: _string(data['warehouse_id']).isNotEmpty
          ? _string(data['warehouse_id'])
          : _string(data['warehouseId']).isNotEmpty
              ? _string(data['warehouseId'])
              : _string(data['warehouse_name']).isNotEmpty
                  ? _string(data['warehouse_name'])
                  : _string(data['warehouse']),
      warehouseName: _string(data['warehouse_name']).isNotEmpty
          ? _string(data['warehouse_name'])
          : _string(data['warehouse']),
      ledgerScope: ledgerScopeFromData(data),
      qtyInitial: qtyInitial,
      qtyRemaining: qtyRemaining,
      unitCost: unitCost,
      totalCost: _num(data['total_cost'] ?? data['totalCost']) > 0
          ? _num(data['total_cost'] ?? data['totalCost'])
          : qtyInitial * unitCost,
      createdAt: _date(data['created_at']) ?? _date(data['createdAt']),
      receivedAt: _date(data['received_at']) ?? _date(data['receivedAt']),
      sourceDocumentId: _string(
        data['source_document_id'] ?? data['source_doc_id'],
      ),
      sourceType: _string(data['source_type'] ?? data['source_doc_type']),
      isActive: data['is_active'] == null
          ? (data['status'] ?? 'ACTIVE').toString().toUpperCase() != 'CLOSED'
          : data['is_active'] == true,
      status: _string(data['status']).isEmpty
          ? 'ACTIVE'
          : _string(data['status']).toUpperCase(),
      raw: Map<String, dynamic>.from(data),
    );
  }
}

class InventoryBatchConsumption {
  const InventoryBatchConsumption({
    required this.batchId,
    required this.qty,
    required this.unitCost,
    required this.totalCost,
    required this.costingMethod,
  });

  final String batchId;
  final double qty;
  final double unitCost;
  final double totalCost;
  final InventoryCostingMethod costingMethod;
}

class InventoryBatchCostingResult {
  const InventoryBatchCostingResult({
    required this.updatedBatches,
    required this.consumptions,
    required this.totalCost,
    required this.totalQtyConsumed,
    required this.remainingQty,
    required this.remainingValue,
    required this.costingMethod,
    required this.unitCostApplied,
  });

  final List<InventoryBatchEntry> updatedBatches;
  final List<InventoryBatchConsumption> consumptions;
  final double totalCost;
  final double totalQtyConsumed;
  final double remainingQty;
  final double remainingValue;
  final InventoryCostingMethod costingMethod;
  final double unitCostApplied;
}

class InventoryBatchPreparationResult {
  const InventoryBatchPreparationResult({
    required this.batches,
    required this.syntheticBatchPayload,
    required this.syntheticBatchId,
  });

  final List<InventoryBatchEntry> batches;
  final Map<String, dynamic>? syntheticBatchPayload;
  final String? syntheticBatchId;
}

class InventoryValuationSnapshot {
  const InventoryValuationSnapshot({
    required this.availableQty,
    required this.totalCost,
    required this.averageUnitCost,
  });

  final double availableQty;
  final double totalCost;
  final double averageUnitCost;
}

List<InventoryBatchEntry> normalizeInventoryBatches({
  required List<InventoryBatchEntry> batches,
  required LedgerScope ledgerScope,
}) {
  return batches.map((batch) {
    if (batch.ledgerScope != ledgerScope) {
      throw InventoryBatchException(
        'Batch ${batch.id} ledger scope does not match requested ledger scope',
      );
    }
    return batch.copyWith(raw: Map<String, dynamic>.from(batch.raw));
  }).toList(growable: true)
    ..sort((a, b) {
      final ad = (a.receivedAt ?? a.createdAt)?.millisecondsSinceEpoch ?? 0;
      final bd = (b.receivedAt ?? b.createdAt)?.millisecondsSinceEpoch ?? 0;
      if (ad != bd) return ad.compareTo(bd);
      return a.id.compareTo(b.id);
    });
}

InventoryValuationSnapshot calculateInventoryValuation({
  required List<InventoryBatchEntry> batches,
  required LedgerScope ledgerScope,
}) {
  final normalized = normalizeInventoryBatches(
    batches: batches,
    ledgerScope: ledgerScope,
  );
  final available = normalized.fold<double>(
    0,
    (total, batch) => total + batch.qtyRemaining,
  );
  final totalCost = normalized.fold<double>(
    0,
    (total, batch) => total + (batch.qtyRemaining * batch.unitCost),
  );
  return InventoryValuationSnapshot(
    availableQty: available,
    totalCost: totalCost,
    averageUnitCost: available <= 0 ? 0 : totalCost / available,
  );
}

void _assertSufficientInventory({
  required double requestedQty,
  required double availableQty,
}) {
  if (requestedQty <= 0) {
    throw const InventoryBatchException('Requested qty must be positive');
  }
  if (availableQty + 1e-9 < requestedQty) {
    throw InventoryBatchException(
      'Insufficient inventory batches: requested $requestedQty, available $availableQty',
    );
  }
}

InventoryBatchCostingResult consumeInventoryBatchesFifo({
  required List<InventoryBatchEntry> batches,
  required LedgerScope ledgerScope,
  required double requestedQty,
}) {
  final normalized = normalizeInventoryBatches(
    batches: batches,
    ledgerScope: ledgerScope,
  );
  final valuation = calculateInventoryValuation(
    batches: normalized,
    ledgerScope: ledgerScope,
  );
  _assertSufficientInventory(
    requestedQty: requestedQty,
    availableQty: valuation.availableQty,
  );

  var qtyLeft = requestedQty;
  final consumptions = <InventoryBatchConsumption>[];
  final updated = <InventoryBatchEntry>[];

  for (final batch in normalized) {
    if (qtyLeft <= 0) {
      updated.add(batch);
      continue;
    }
    if (batch.qtyRemaining <= 0) {
      updated.add(batch);
      continue;
    }
    final used = qtyLeft < batch.qtyRemaining ? qtyLeft : batch.qtyRemaining;
    final nextRemaining = batch.qtyRemaining - used;
    consumptions.add(
      InventoryBatchConsumption(
        batchId: batch.id,
        qty: used,
        unitCost: batch.unitCost,
        totalCost: used * batch.unitCost,
        costingMethod: InventoryCostingMethod.fifo,
      ),
    );
    updated.add(batch.copyWith(qtyRemaining: nextRemaining));
    qtyLeft -= used;
  }

  final totalCost = consumptions.fold<double>(
    0,
    (total, item) => total + item.totalCost,
  );
  final remainingQty = updated.fold<double>(
    0,
    (total, batch) => total + batch.qtyRemaining,
  );
  final remainingValue = updated.fold<double>(
    0,
    (total, batch) => total + (batch.qtyRemaining * batch.unitCost),
  );

  return InventoryBatchCostingResult(
    updatedBatches: updated,
    consumptions: consumptions,
    totalCost: totalCost,
    totalQtyConsumed: requestedQty,
    remainingQty: remainingQty,
    remainingValue: remainingValue,
    costingMethod: InventoryCostingMethod.fifo,
    unitCostApplied: requestedQty <= 0 ? 0 : totalCost / requestedQty,
  );
}

InventoryBatchCostingResult consumeInventoryBatchesWeightedAverage({
  required List<InventoryBatchEntry> batches,
  required LedgerScope ledgerScope,
  required double requestedQty,
}) {
  final normalized = normalizeInventoryBatches(
    batches: batches,
    ledgerScope: ledgerScope,
  );
  final valuation = calculateInventoryValuation(
    batches: normalized,
    ledgerScope: ledgerScope,
  );
  _assertSufficientInventory(
    requestedQty: requestedQty,
    availableQty: valuation.availableQty,
  );

  var qtyLeft = requestedQty;
  final updated = <InventoryBatchEntry>[];
  for (var i = 0; i < normalized.length; i++) {
    final batch = normalized[i];
    if (batch.qtyRemaining <= 0) {
      updated.add(batch);
      continue;
    }

    double used;
    if (i == normalized.length - 1) {
      used = qtyLeft;
    } else {
      used = requestedQty * (batch.qtyRemaining / valuation.availableQty);
      if (used > qtyLeft) used = qtyLeft;
      if (used > batch.qtyRemaining) used = batch.qtyRemaining;
    }
    final nextRemaining = batch.qtyRemaining - used;
    updated.add(
        batch.copyWith(qtyRemaining: nextRemaining < 0 ? 0 : nextRemaining));
    qtyLeft -= used;
    if (qtyLeft < 1e-9) qtyLeft = 0;
  }

  final totalCost = valuation.averageUnitCost * requestedQty;
  final remainingQty = valuation.availableQty - requestedQty;
  final remainingValue = valuation.totalCost - totalCost;
  final consumption = InventoryBatchConsumption(
    batchId: '',
    qty: requestedQty,
    unitCost: valuation.averageUnitCost,
    totalCost: totalCost,
    costingMethod: InventoryCostingMethod.weightedAverage,
  );

  return InventoryBatchCostingResult(
    updatedBatches: updated,
    consumptions: [consumption],
    totalCost: totalCost,
    totalQtyConsumed: requestedQty,
    remainingQty: remainingQty < 0 ? 0 : remainingQty,
    remainingValue: remainingValue < 0 ? 0 : remainingValue,
    costingMethod: InventoryCostingMethod.weightedAverage,
    unitCostApplied: valuation.averageUnitCost,
  );
}

InventoryBatchCostingResult consumeInventoryBatches({
  required List<InventoryBatchEntry> batches,
  required LedgerScope ledgerScope,
  required double requestedQty,
  required InventoryCostingMethod costingMethod,
}) {
  switch (costingMethod) {
    case InventoryCostingMethod.weightedAverage:
      return consumeInventoryBatchesWeightedAverage(
        batches: batches,
        ledgerScope: ledgerScope,
        requestedQty: requestedQty,
      );
    case InventoryCostingMethod.fifo:
      return consumeInventoryBatchesFifo(
        batches: batches,
        ledgerScope: ledgerScope,
        requestedQty: requestedQty,
      );
  }
}

Map<String, dynamic> buildInventoryBatchPayload({
  required String companyId,
  required String productId,
  required String productName,
  required String warehouseId,
  required String warehouseName,
  required LedgerScope ledgerScope,
  required double qtyInitial,
  required double qtyRemaining,
  required double unitCost,
  double? totalCost,
  required String sourceDocType,
  required String sourceDocId,
  String? sourceItemId,
  bool isLegacyCache = false,
  DateTime? receivedAt,
  bool isActive = true,
  String status = 'ACTIVE',
  Map<String, dynamic> extra = const {},
}) {
  return <String, dynamic>{
    'idCompany': companyId.trim(),
    'product_id': productId.trim(),
    'product_name': productName.trim(),
    'warehouse_id': warehouseId.trim(),
    'warehouse_name': warehouseName.trim(),
    ...ledgerScopeFields(ledgerScope: ledgerScope),
    'qty_initial': qtyInitial,
    'qty_remaining': qtyRemaining,
    'unit_cost': unitCost,
    'total_cost': totalCost ?? (qtyRemaining * unitCost),
    'received_at': receivedAt ?? FieldValue.serverTimestamp(),
    'source_document_id': sourceDocId.trim(),
    'source_type': sourceDocType.trim(),
    'source_doc_type': sourceDocType.trim(),
    'source_doc_id': sourceDocId.trim(),
    'source_item_id': sourceItemId?.trim(),
    'is_legacy_cache': isLegacyCache,
    'is_active': isActive,
    'status': status.trim().isEmpty ? 'ACTIVE' : status.trim().toUpperCase(),
    'created_at': FieldValue.serverTimestamp(),
    'updated_at': FieldValue.serverTimestamp(),
    ...extra,
  }..removeWhere((key, value) => value == null);
}

Map<String, dynamic> buildSaleItemCogsPayload({
  required String companyId,
  required String saleId,
  required String saleItemId,
  required String productId,
  required String productName,
  required String warehouseId,
  required String warehouseName,
  required LedgerScope ledgerScope,
  required InventoryBatchConsumption consumption,
  required InventoryCostingMethod costingMethod,
  required double unitCostApplied,
}) {
  return <String, dynamic>{
    'idCompany': companyId.trim(),
    'sale_id': saleId.trim(),
    'sale_item_id': saleItemId.trim(),
    'batch_id': consumption.batchId.isEmpty ? null : consumption.batchId,
    'product_id': productId.trim(),
    'product_name': productName.trim(),
    'warehouse_id': warehouseId.trim(),
    'warehouse_name': warehouseName.trim(),
    ...ledgerScopeFields(ledgerScope: ledgerScope),
    ...inventoryCostingMethodFields(costingMethod),
    'qty': consumption.qty,
    'unit_cost': consumption.unitCost,
    'unit_cost_applied': unitCostApplied,
    'cost_basis_unit_cost': unitCostApplied,
    'total_cost': consumption.totalCost,
    'created_at': FieldValue.serverTimestamp(),
  }..removeWhere((key, value) => value == null);
}

Map<String, dynamic> buildCogsEntryPayload({
  required String companyId,
  required String saleId,
  required String saleItemId,
  required String productId,
  required String productName,
  required String warehouseId,
  required String warehouseName,
  required LedgerScope ledgerScope,
  required InventoryBatchConsumption consumption,
  required InventoryCostingMethod costingMethod,
  required double unitCostApplied,
}) {
  return <String, dynamic>{
    'idCompany': companyId.trim(),
    'item_kind': 'product',
    'sale_id': saleId.trim(),
    'sale_item_id': saleItemId.trim(),
    'product_id': productId.trim(),
    'product_name': productName.trim(),
    'warehouse_id': warehouseId.trim(),
    'warehouse_name': warehouseName.trim(),
    ...ledgerScopeFields(ledgerScope: ledgerScope),
    ...inventoryCostingMethodFields(costingMethod),
    'quantity': consumption.qty,
    'qty': consumption.qty,
    'unit_cost': unitCostApplied,
    'cost_basis_unit_cost': unitCostApplied,
    'total_cost': consumption.totalCost,
    'batch_id': consumption.batchId.isEmpty ? null : consumption.batchId,
    'source_batch_id': consumption.batchId.isEmpty ? null : consumption.batchId,
    'created_at': FieldValue.serverTimestamp(),
  }..removeWhere((key, value) => value == null);
}

Map<String, dynamic> buildBatchConsumptionPayload({
  required String companyId,
  required String saleId,
  required String saleItemId,
  required LedgerScope ledgerScope,
  required InventoryBatchConsumption consumption,
}) {
  return <String, dynamic>{
    'idCompany': companyId.trim(),
    'sale_id': saleId.trim(),
    'sale_item_id': saleItemId.trim(),
    'batch_id': consumption.batchId.isEmpty ? null : consumption.batchId,
    'source_batch_id': consumption.batchId.isEmpty ? null : consumption.batchId,
    ...ledgerScopeFields(ledgerScope: ledgerScope),
    'quantity': consumption.qty,
    'qty': consumption.qty,
    'unit_cost': consumption.unitCost,
    'total_cost': consumption.totalCost,
    'created_at': FieldValue.serverTimestamp(),
  }..removeWhere((key, value) => value == null);
}

Map<String, dynamic> buildLegacyInventoryBackfillBatchPayload({
  required String companyId,
  required String productId,
  required String productName,
  required String warehouseId,
  required String warehouseName,
  required LedgerScope ledgerScope,
  required double qtyRemaining,
  required double unitCost,
}) {
  return buildInventoryBatchPayload(
    companyId: companyId,
    productId: productId,
    productName: productName,
    warehouseId: warehouseId,
    warehouseName: warehouseName,
    ledgerScope: ledgerScope,
    qtyInitial: qtyRemaining,
    qtyRemaining: qtyRemaining,
    unitCost: unitCost,
    sourceDocType: 'legacy_cache',
    sourceDocId: productId,
    isLegacyCache: true,
  );
}

InventoryBatchPreparationResult prepareInventoryBatchesForSale({
  required String companyId,
  required String productId,
  required String productName,
  required String warehouseId,
  required String warehouseName,
  required LedgerScope ledgerScope,
  required List<InventoryBatchEntry> existingBatches,
  required double stockQty,
  required double unitCost,
  required String syntheticBatchId,
}) {
  final relevantBatches = existingBatches
      .where((batch) =>
          batch.warehouseId == warehouseId && batch.ledgerScope == ledgerScope)
      .toList();
  final batchQty = relevantBatches.fold<double>(
    0,
    (total, batch) => total + batch.qtyRemaining,
  );

  if (batchQty + 1e-9 >= stockQty) {
    return InventoryBatchPreparationResult(
      batches: relevantBatches,
      syntheticBatchPayload: null,
      syntheticBatchId: null,
    );
  }

  final gapQty = stockQty - batchQty;
  if (gapQty <= 1e-9) {
    return InventoryBatchPreparationResult(
      batches: relevantBatches,
      syntheticBatchPayload: null,
      syntheticBatchId: null,
    );
  }

  if (relevantBatches.isNotEmpty) {
    throw InventoryBatchException(
      'Inventory batch mismatch for $productName: cache stock $stockQty exceeds batch stock $batchQty',
    );
  }

  final syntheticPayload = buildLegacyInventoryBackfillBatchPayload(
    companyId: companyId,
    productId: productId,
    productName: productName,
    warehouseId: warehouseId,
    warehouseName: warehouseName,
    ledgerScope: ledgerScope,
    qtyRemaining: gapQty,
    unitCost: unitCost,
  );

  return InventoryBatchPreparationResult(
    batches: [
      ...relevantBatches,
      InventoryBatchEntry(
        id: syntheticBatchId,
        companyId: companyId,
        productId: productId,
        productName: productName,
        warehouseId: warehouseId,
        warehouseName: warehouseName,
        ledgerScope: ledgerScope,
        qtyInitial: gapQty,
        qtyRemaining: gapQty,
        unitCost: unitCost,
        totalCost: gapQty * unitCost,
        createdAt: null,
        receivedAt: null,
        sourceDocumentId: productId,
        sourceType: 'legacy_cache',
        isActive: true,
        status: 'ACTIVE',
        raw: const <String, dynamic>{},
      ),
    ],
    syntheticBatchPayload: syntheticPayload,
    syntheticBatchId: syntheticBatchId,
  );
}
