import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/utils/device_management_support.dart';

class DeviceCommandRecord extends FirestoreRecord {
  DeviceCommandRecord._(super.reference, super.data) {
    _initializeFields();
  }

  String? _deviceId;
  String get deviceId => _deviceId ?? '';

  String? _commandType;
  String get commandType => _commandType ?? '';
  DeviceCommandType get commandTypeEnum =>
      deviceCommandTypeFromValue(_commandType);

  String? _status;
  String get status => _status ?? '';
  DeviceCommandStatus get statusEnum => deviceCommandStatusFromValue(_status);

  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;

  DateTime? _executedAt;
  DateTime? get executedAt => _executedAt;

  void _initializeFields() {
    _deviceId = snapshotData['device_id'] as String?;
    _commandType = snapshotData['command_type'] as String?;
    _status = snapshotData['status'] as String?;
    _createdAt = snapshotData['created_at'] as DateTime?;
    _executedAt = snapshotData['executed_at'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('device_commands');

  static DeviceCommandRecord fromSnapshot(DocumentSnapshot snapshot) =>
      DeviceCommandRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );
}

Map<String, dynamic> createDeviceCommandRecordData({
  String? deviceId,
  String? commandType,
  String? status,
  DateTime? createdAt,
  DateTime? executedAt,
}) {
  return mapToFirestore(
    <String, dynamic>{
      'device_id': deviceId,
      'command_type': commandType,
      'status': status,
      'created_at': createdAt,
      'executed_at': executedAt,
    }.withoutNulls,
  );
}

class DeviceCommandRecordDocumentEquality
    implements Equality<DeviceCommandRecord> {
  const DeviceCommandRecordDocumentEquality();

  @override
  bool equals(DeviceCommandRecord? e1, DeviceCommandRecord? e2) =>
      e1?.deviceId == e2?.deviceId &&
      e1?.commandType == e2?.commandType &&
      e1?.status == e2?.status;

  @override
  int hash(DeviceCommandRecord? e) =>
      const ListEquality().hash([e?.deviceId, e?.commandType, e?.status]);

  @override
  bool isValidKey(Object? o) => o is DeviceCommandRecord;
}
