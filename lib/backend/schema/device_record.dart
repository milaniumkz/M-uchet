import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/utils/device_management_support.dart';

class DeviceRecord extends FirestoreRecord {
  DeviceRecord._(super.reference, super.data) {
    _initializeFields();
  }

  String? _deviceId;
  String get deviceId => _deviceId ?? '';

  String? _userId;
  String get userId => _userId ?? '';

  String? _status;
  String get status => _status ?? '';
  DeviceStatus get statusEnum => deviceStatusFromValue(_status);

  DateTime? _lastSeenAt;
  DateTime? get lastSeenAt => _lastSeenAt;

  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;

  void _initializeFields() {
    _deviceId = snapshotData['device_id'] as String?;
    _userId = snapshotData['user_id'] as String?;
    _status = snapshotData['status'] as String?;
    _lastSeenAt = snapshotData['last_seen_at'] as DateTime?;
    _createdAt = snapshotData['created_at'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('devices');

  static DeviceRecord fromSnapshot(DocumentSnapshot snapshot) => DeviceRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );
}

Map<String, dynamic> createDeviceRecordData({
  String? deviceId,
  String? userId,
  String? status,
  DateTime? lastSeenAt,
  DateTime? createdAt,
}) {
  return mapToFirestore(
    <String, dynamic>{
      'device_id': deviceId,
      'user_id': userId,
      'status': status,
      'last_seen_at': lastSeenAt,
      'created_at': createdAt,
    }.withoutNulls,
  );
}

class DeviceRecordDocumentEquality implements Equality<DeviceRecord> {
  const DeviceRecordDocumentEquality();

  @override
  bool equals(DeviceRecord? e1, DeviceRecord? e2) =>
      e1?.deviceId == e2?.deviceId &&
      e1?.userId == e2?.userId &&
      e1?.status == e2?.status;

  @override
  int hash(DeviceRecord? e) =>
      const ListEquality().hash([e?.deviceId, e?.userId, e?.status]);

  @override
  bool isValidKey(Object? o) => o is DeviceRecord;
}
