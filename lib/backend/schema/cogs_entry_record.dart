import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/utils/ledger_scope.dart';

class CogsEntryRecord extends FirestoreRecord {
  CogsEntryRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  String? _saleId;
  String get saleId => _saleId ?? '';

  String? _saleItemId;
  String get saleItemId => _saleItemId ?? '';

  String? _productId;
  String get productId => _productId ?? '';

  String? _serviceId;
  String get serviceId => _serviceId ?? '';

  String? _warehouseId;
  String get warehouseId => _warehouseId ?? '';

  String? _ledgerScope;
  String get ledgerScope => _ledgerScope ?? '';
  LedgerScope get ledgerScopeEnum => ledgerScopeFromLegacyValue(_ledgerScope);

  String? _costingMethod;
  String get costingMethod => _costingMethod ?? '';

  double? _quantity;
  double get quantity => _quantity ?? 0;

  double? _unitCost;
  double get unitCost => _unitCost ?? 0;

  double? _totalCost;
  double get totalCost => _totalCost ?? 0;

  String? _batchId;
  String get batchId => _batchId ?? '';

  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;

  void _initializeFields() {
    _saleId = snapshotData['sale_id'] as String?;
    _saleItemId = snapshotData['sale_item_id'] as String?;
    _productId = snapshotData['product_id'] as String?;
    _serviceId = snapshotData['service_id'] as String?;
    _warehouseId = snapshotData['warehouse_id'] as String?;
    _ledgerScope = (snapshotData['ledger_scope'] ?? snapshotData['ledgerScope'])
        as String?;
    _costingMethod = (snapshotData['costing_method'] ??
        snapshotData['costingMethod']) as String?;
    _quantity =
        castToType<double>(snapshotData['quantity'] ?? snapshotData['qty']);
    _unitCost = castToType<double>(
        snapshotData['unit_cost'] ?? snapshotData['unitCost']);
    _totalCost = castToType<double>(
      snapshotData['total_cost'] ?? snapshotData['totalCost'],
    );
    _batchId = (snapshotData['batch_id'] ?? snapshotData['source_batch_id'])
        as String?;
    _createdAt = snapshotData['created_at'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('cogs_register');

  static Stream<CogsEntryRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => CogsEntryRecord.fromSnapshot(s));

  static Future<CogsEntryRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => CogsEntryRecord.fromSnapshot(s));

  static CogsEntryRecord fromSnapshot(DocumentSnapshot snapshot) =>
      CogsEntryRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );

  static CogsEntryRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      CogsEntryRecord._(reference, mapFromFirestore(data));
}

Map<String, dynamic> createCogsEntryRecordData({
  String? saleId,
  String? saleItemId,
  String? productId,
  String? serviceId,
  String? warehouseId,
  String? ledgerScope,
  String? costingMethod,
  double? quantity,
  double? unitCost,
  double? totalCost,
  String? batchId,
  DateTime? createdAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'sale_id': saleId,
      'sale_item_id': saleItemId,
      'product_id': productId,
      'service_id': serviceId,
      'warehouse_id': warehouseId,
      'ledger_scope': ledgerScope,
      'ledgerScope': ledgerScope,
      'costing_method': costingMethod,
      'costingMethod': costingMethod,
      'quantity': quantity,
      'unit_cost': unitCost,
      'total_cost': totalCost,
      'batch_id': batchId,
      'created_at': createdAt,
    }.withoutNulls,
  );

  return firestoreData;
}

CogsEntryRecordDocumentEquality get cogsEntryRecordDocumentEquality =>
    const CogsEntryRecordDocumentEquality();

class CogsEntryRecordDocumentEquality implements Equality<CogsEntryRecord> {
  const CogsEntryRecordDocumentEquality();

  @override
  bool equals(CogsEntryRecord? e1, CogsEntryRecord? e2) =>
      e1?.saleId == e2?.saleId &&
      e1?.saleItemId == e2?.saleItemId &&
      e1?.productId == e2?.productId &&
      e1?.serviceId == e2?.serviceId &&
      e1?.warehouseId == e2?.warehouseId &&
      e1?.ledgerScope == e2?.ledgerScope &&
      e1?.costingMethod == e2?.costingMethod &&
      e1?.quantity == e2?.quantity &&
      e1?.unitCost == e2?.unitCost &&
      e1?.totalCost == e2?.totalCost &&
      e1?.batchId == e2?.batchId;

  @override
  int hash(CogsEntryRecord? e) => const ListEquality().hash([
        e?.saleId,
        e?.saleItemId,
        e?.productId,
        e?.serviceId,
        e?.warehouseId,
        e?.ledgerScope,
        e?.costingMethod,
        e?.quantity,
        e?.unitCost,
        e?.totalCost,
        e?.batchId,
      ]);

  @override
  bool isValidKey(Object? o) => o is CogsEntryRecord;
}
