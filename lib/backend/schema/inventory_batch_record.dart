import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/utils/ledger_scope.dart';

class InventoryBatchRecord extends FirestoreRecord {
  InventoryBatchRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  String? _productId;
  String get productId => _productId ?? '';
  bool hasProductId() => _productId != null;

  String? _warehouseId;
  String get warehouseId => _warehouseId ?? '';
  bool hasWarehouseId() => _warehouseId != null;

  String? _ledgerScope;
  String get ledgerScope => _ledgerScope ?? '';
  bool hasLedgerScope() => _ledgerScope != null;
  LedgerScope get ledgerScopeEnum => ledgerScopeFromLegacyValue(_ledgerScope);

  double? _qtyInitial;
  double get qtyInitial => _qtyInitial ?? 0;
  bool hasQtyInitial() => _qtyInitial != null;

  double? _qtyRemaining;
  double get qtyRemaining => _qtyRemaining ?? 0;
  bool hasQtyRemaining() => _qtyRemaining != null;

  double? _unitCost;
  double get unitCost => _unitCost ?? 0;
  bool hasUnitCost() => _unitCost != null;

  double? _totalCost;
  double get totalCost => _totalCost ?? 0;
  bool hasTotalCost() => _totalCost != null;

  DateTime? _receivedAt;
  DateTime? get receivedAt => _receivedAt;
  bool hasReceivedAt() => _receivedAt != null;

  String? _sourceDocumentId;
  String get sourceDocumentId => _sourceDocumentId ?? '';
  bool hasSourceDocumentId() => _sourceDocumentId != null;

  String? _sourceType;
  String get sourceType => _sourceType ?? '';
  bool hasSourceType() => _sourceType != null;

  bool? _isActive;
  bool get isActive => _isActive ?? false;
  bool hasIsActive() => _isActive != null;

  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  void _initializeFields() {
    _productId = snapshotData['product_id'] as String?;
    _warehouseId = (snapshotData['warehouse_id'] ?? snapshotData['warehouseId'])
        as String?;
    _ledgerScope = (snapshotData['ledger_scope'] ?? snapshotData['ledgerScope'])
        as String?;
    _qtyInitial = castToType<double>(
        snapshotData['qty_initial'] ?? snapshotData['qtyInitial']);
    _qtyRemaining = castToType<double>(
      snapshotData['qty_remaining'] ?? snapshotData['qtyRemaining'],
    );
    _unitCost = castToType<double>(
        snapshotData['unit_cost'] ?? snapshotData['unitCost']);
    _totalCost = castToType<double>(
        snapshotData['total_cost'] ?? snapshotData['totalCost']);
    _createdAt =
        (snapshotData['created_at'] ?? snapshotData['createdAt']) as DateTime?;
    _receivedAt = (snapshotData['received_at'] ?? snapshotData['receivedAt'])
        as DateTime?;
    _sourceDocumentId = (snapshotData['source_document_id'] ??
        snapshotData['source_doc_id']) as String?;
    _sourceType = (snapshotData['source_type'] ??
        snapshotData['source_doc_type']) as String?;
    _isActive = snapshotData['is_active'] as bool?;
    _status = snapshotData['status'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('inventory_batches');

  static Stream<InventoryBatchRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => InventoryBatchRecord.fromSnapshot(s));

  static Future<InventoryBatchRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => InventoryBatchRecord.fromSnapshot(s));

  static InventoryBatchRecord fromSnapshot(DocumentSnapshot snapshot) =>
      InventoryBatchRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );

  static InventoryBatchRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      InventoryBatchRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'InventoryBatchRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is InventoryBatchRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createInventoryBatchRecordData({
  String? productId,
  String? warehouseId,
  String? ledgerScope,
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
}) {
  return mapToFirestore(
    <String, dynamic>{
      'product_id': productId,
      'warehouse_id': warehouseId,
      'ledger_scope': ledgerScope,
      'ledgerScope': ledgerScope,
      'qty_initial': qtyInitial,
      'qty_remaining': qtyRemaining,
      'unit_cost': unitCost,
      'total_cost': totalCost,
      'created_at': createdAt,
      'received_at': receivedAt,
      'source_document_id': sourceDocumentId,
      'source_type': sourceType,
      'is_active': isActive,
      'status': status,
    }.withoutNulls,
  );
}

class InventoryBatchRecordDocumentEquality
    implements Equality<InventoryBatchRecord> {
  const InventoryBatchRecordDocumentEquality();

  @override
  bool equals(InventoryBatchRecord? e1, InventoryBatchRecord? e2) {
    return e1?.productId == e2?.productId &&
        e1?.warehouseId == e2?.warehouseId &&
        e1?.ledgerScope == e2?.ledgerScope &&
        e1?.qtyInitial == e2?.qtyInitial &&
        e1?.qtyRemaining == e2?.qtyRemaining &&
        e1?.unitCost == e2?.unitCost &&
        e1?.totalCost == e2?.totalCost &&
        e1?.createdAt == e2?.createdAt &&
        e1?.receivedAt == e2?.receivedAt &&
        e1?.sourceDocumentId == e2?.sourceDocumentId &&
        e1?.sourceType == e2?.sourceType &&
        e1?.isActive == e2?.isActive &&
        e1?.status == e2?.status;
  }

  @override
  int hash(InventoryBatchRecord? e) => const ListEquality().hash([
        e?.productId,
        e?.warehouseId,
        e?.ledgerScope,
        e?.qtyInitial,
        e?.qtyRemaining,
        e?.unitCost,
        e?.totalCost,
        e?.createdAt,
        e?.receivedAt,
        e?.sourceDocumentId,
        e?.sourceType,
        e?.isActive,
        e?.status,
      ]);

  @override
  bool isValidKey(Object? o) => o is InventoryBatchRecord;
}
