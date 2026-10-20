import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/utils/ledger_scope.dart';

class BatchConsumptionRecord extends FirestoreRecord {
  BatchConsumptionRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  String? _batchId;
  String get batchId => _batchId ?? '';

  String? _saleItemId;
  String get saleItemId => _saleItemId ?? '';

  String? _saleId;
  String get saleId => _saleId ?? '';

  double? _quantity;
  double get quantity => _quantity ?? 0;

  double? _unitCost;
  double get unitCost => _unitCost ?? 0;

  double? _totalCost;
  double get totalCost => _totalCost ?? 0;

  String? _sourceBatchId;
  String get sourceBatchId => _sourceBatchId ?? '';

  String? _ledgerScope;
  String get ledgerScope => _ledgerScope ?? '';
  LedgerScope get ledgerScopeEnum => ledgerScopeFromLegacyValue(_ledgerScope);

  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;

  void _initializeFields() {
    _batchId = snapshotData['batch_id'] as String?;
    _saleItemId = snapshotData['sale_item_id'] as String?;
    _saleId = snapshotData['sale_id'] as String?;
    _quantity =
        castToType<double>(snapshotData['quantity'] ?? snapshotData['qty']);
    _unitCost = castToType<double>(
        snapshotData['unit_cost'] ?? snapshotData['unitCost']);
    _totalCost = castToType<double>(
      snapshotData['total_cost'] ?? snapshotData['totalCost'],
    );
    _sourceBatchId = (snapshotData['source_batch_id'] ??
        snapshotData['sourceBatchId']) as String?;
    _ledgerScope = (snapshotData['ledger_scope'] ?? snapshotData['ledgerScope'])
        as String?;
    _createdAt = snapshotData['created_at'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('batch_consumptions');

  static Stream<BatchConsumptionRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => BatchConsumptionRecord.fromSnapshot(s));

  static Future<BatchConsumptionRecord> getDocumentOnce(
          DocumentReference ref) =>
      ref.get().then((s) => BatchConsumptionRecord.fromSnapshot(s));

  static BatchConsumptionRecord fromSnapshot(DocumentSnapshot snapshot) =>
      BatchConsumptionRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );

  static BatchConsumptionRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      BatchConsumptionRecord._(reference, mapFromFirestore(data));
}

Map<String, dynamic> createBatchConsumptionRecordData({
  String? batchId,
  String? saleItemId,
  String? saleId,
  double? quantity,
  double? unitCost,
  double? totalCost,
  String? sourceBatchId,
  String? ledgerScope,
  DateTime? createdAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'batch_id': batchId,
      'sale_item_id': saleItemId,
      'sale_id': saleId,
      'quantity': quantity,
      'unit_cost': unitCost,
      'total_cost': totalCost,
      'source_batch_id': sourceBatchId,
      'ledger_scope': ledgerScope,
      'ledgerScope': ledgerScope,
      'created_at': createdAt,
    }.withoutNulls,
  );

  return firestoreData;
}

BatchConsumptionRecordDocumentEquality
    get batchConsumptionRecordDocumentEquality =>
        const BatchConsumptionRecordDocumentEquality();

class BatchConsumptionRecordDocumentEquality
    implements Equality<BatchConsumptionRecord> {
  const BatchConsumptionRecordDocumentEquality();

  @override
  bool equals(BatchConsumptionRecord? e1, BatchConsumptionRecord? e2) =>
      e1?.batchId == e2?.batchId &&
      e1?.saleItemId == e2?.saleItemId &&
      e1?.saleId == e2?.saleId &&
      e1?.quantity == e2?.quantity &&
      e1?.unitCost == e2?.unitCost &&
      e1?.totalCost == e2?.totalCost &&
      e1?.sourceBatchId == e2?.sourceBatchId &&
      e1?.ledgerScope == e2?.ledgerScope;

  @override
  int hash(BatchConsumptionRecord? e) => const ListEquality().hash([
        e?.batchId,
        e?.saleItemId,
        e?.saleId,
        e?.quantity,
        e?.unitCost,
        e?.totalCost,
        e?.sourceBatchId,
        e?.ledgerScope,
      ]);

  @override
  bool isValidKey(Object? o) => o is BatchConsumptionRecord;
}
