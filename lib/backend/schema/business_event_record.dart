import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/utils/business_event_support.dart';
import '/utils/ledger_scope.dart';

class BusinessEventRecord extends FirestoreRecord {
  BusinessEventRecord._(super.reference, super.data) {
    _initializeFields();
  }

  String? _eventType;
  String get eventType => _eventType ?? '';
  BusinessEventType get eventTypeEnum => businessEventTypeFromValue(_eventType);

  String? _ledgerScope;
  String get ledgerScope => _ledgerScope ?? '';
  LedgerScope get ledgerScopeEnum => ledgerScopeFromLegacyValue(_ledgerScope);

  double? _revenue;
  double get revenue => _revenue ?? 0;

  double? _cost;
  double get cost => _cost ?? 0;

  double? _margin;
  double get margin => _margin ?? 0;

  String? _warehouseId;
  String get warehouseId => _warehouseId ?? '';

  DateTime? _occurredAt;
  DateTime? get occurredAt => _occurredAt;

  void _initializeFields() {
    _eventType = snapshotData['event_type'] as String?;
    _ledgerScope = snapshotData['ledger_scope'] as String?;
    _revenue = castToType<double>(snapshotData['revenue']);
    _cost = castToType<double>(snapshotData['cost']);
    _margin = castToType<double>(snapshotData['margin']);
    _warehouseId = snapshotData['warehouse_id'] as String?;
    _occurredAt = snapshotData['occurred_at'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('business_events');

  static BusinessEventRecord fromSnapshot(DocumentSnapshot snapshot) =>
      BusinessEventRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );
}

Map<String, dynamic> createBusinessEventRecordData({
  String? eventType,
  String? ledgerScope,
  double? revenue,
  double? cost,
  double? margin,
  String? warehouseId,
  DateTime? occurredAt,
}) {
  return mapToFirestore(
    <String, dynamic>{
      'event_type': eventType,
      'ledger_scope': ledgerScope,
      'revenue': revenue,
      'cost': cost,
      'margin': margin,
      'warehouse_id': warehouseId,
      'occurred_at': occurredAt,
    }.withoutNulls,
  );
}

class BusinessEventRecordDocumentEquality
    implements Equality<BusinessEventRecord> {
  const BusinessEventRecordDocumentEquality();

  @override
  bool equals(BusinessEventRecord? e1, BusinessEventRecord? e2) =>
      e1?.eventType == e2?.eventType &&
      e1?.ledgerScope == e2?.ledgerScope &&
      e1?.warehouseId == e2?.warehouseId &&
      e1?.revenue == e2?.revenue &&
      e1?.cost == e2?.cost &&
      e1?.margin == e2?.margin;

  @override
  int hash(BusinessEventRecord? e) => const ListEquality().hash([
        e?.eventType,
        e?.ledgerScope,
        e?.warehouseId,
        e?.revenue,
        e?.cost,
        e?.margin,
      ]);

  @override
  bool isValidKey(Object? o) => o is BusinessEventRecord;
}
