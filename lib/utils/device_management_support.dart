import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/utils/crypto_wipe_support.dart';

enum DeviceStatus {
  active,
  blocked,
  wiped,
}

enum DeviceCommandType {
  lockApp,
  wipeData,
  forceLogout,
}

enum DeviceCommandStatus {
  pending,
  executed,
  failed,
}

class DeviceCommandExecutionResult {
  const DeviceCommandExecutionResult({
    required this.status,
    required this.requiresLogout,
    required this.wasWiped,
    this.message = '',
  });

  final DeviceCommandStatus status;
  final bool requiresLogout;
  final bool wasWiped;
  final String message;
}

extension DeviceStatusX on DeviceStatus {
  String get storageValue {
    switch (this) {
      case DeviceStatus.active:
        return 'ACTIVE';
      case DeviceStatus.blocked:
        return 'BLOCKED';
      case DeviceStatus.wiped:
        return 'WIPED';
    }
  }
}

extension DeviceCommandTypeX on DeviceCommandType {
  String get storageValue {
    switch (this) {
      case DeviceCommandType.lockApp:
        return 'LOCK_APP';
      case DeviceCommandType.wipeData:
        return 'WIPE_DATA';
      case DeviceCommandType.forceLogout:
        return 'FORCE_LOGOUT';
    }
  }
}

extension DeviceCommandStatusX on DeviceCommandStatus {
  String get storageValue {
    switch (this) {
      case DeviceCommandStatus.pending:
        return 'PENDING';
      case DeviceCommandStatus.executed:
        return 'EXECUTED';
      case DeviceCommandStatus.failed:
        return 'FAILED';
    }
  }
}

DeviceStatus deviceStatusFromValue(String? raw) {
  switch ((raw ?? '').trim().toUpperCase()) {
    case 'BLOCKED':
      return DeviceStatus.blocked;
    case 'WIPED':
      return DeviceStatus.wiped;
    default:
      return DeviceStatus.active;
  }
}

DeviceCommandType deviceCommandTypeFromValue(String? raw) {
  switch ((raw ?? '').trim().toUpperCase()) {
    case 'WIPE_DATA':
      return DeviceCommandType.wipeData;
    case 'FORCE_LOGOUT':
      return DeviceCommandType.forceLogout;
    default:
      return DeviceCommandType.lockApp;
  }
}

DeviceCommandStatus deviceCommandStatusFromValue(String? raw) {
  switch ((raw ?? '').trim().toUpperCase()) {
    case 'EXECUTED':
      return DeviceCommandStatus.executed;
    case 'FAILED':
      return DeviceCommandStatus.failed;
    default:
      return DeviceCommandStatus.pending;
  }
}

Future<String> resolveCurrentDeviceId({
  SharedPreferences? prefs,
}) async {
  final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
  final existing = (resolvedPrefs.getString('ff_device_id') ?? '').trim();
  if (existing.isNotEmpty) return existing;
  final generated = _generateDeviceId();
  await resolvedPrefs.setString('ff_device_id', generated);
  return generated;
}

Map<String, dynamic> buildDevicePayload({
  required String companyId,
  required String deviceId,
  required String userId,
  required DeviceStatus status,
  DateTime? lastSeenAt,
  DateTime? createdAt,
}) {
  return <String, dynamic>{
    'idCompany': companyId,
    'device_id': deviceId,
    'user_id': userId,
    'status': status.storageValue,
    'last_seen_at': lastSeenAt ?? DateTime.now(),
    'created_at': createdAt ?? DateTime.now(),
    'updated_at': DateTime.now(),
  };
}

Map<String, dynamic> buildDeviceCommandPayload({
  required String companyId,
  required String deviceId,
  required String issuedByUserId,
  required DeviceCommandType commandType,
  DeviceCommandStatus status = DeviceCommandStatus.pending,
  String? reason,
  DateTime? createdAt,
  DateTime? executedAt,
}) {
  return <String, dynamic>{
    'idCompany': companyId,
    'device_id': deviceId,
    'command_type': commandType.storageValue,
    'status': status.storageValue,
    'issued_by_user_id': issuedByUserId,
    'reason': reason,
    'created_at': createdAt ?? DateTime.now(),
    'executed_at': executedAt,
    'updated_at': DateTime.now(),
  }..removeWhere((key, value) => value == null);
}

Future<DeviceCommandExecutionResult> executeDeviceCommand({
  required Map<String, dynamic> command,
  SharedPreferences? prefs,
}) async {
  final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
  final type = deviceCommandTypeFromValue(
    (command['command_type'] ?? command['commandType'])?.toString(),
  );
  switch (type) {
    case DeviceCommandType.lockApp:
      await resolvedPrefs.setString(
        'ff_device_status',
        DeviceStatus.blocked.storageValue,
      );
      await resolvedPrefs.setString(
        'ff_device_lock_reason',
        (command['reason'] ?? '').toString(),
      );
      return const DeviceCommandExecutionResult(
        status: DeviceCommandStatus.executed,
        requiresLogout: true,
        wasWiped: false,
        message: 'Device locked',
      );
    case DeviceCommandType.forceLogout:
      await resolvedPrefs.setString(
        'ff_device_status',
        DeviceStatus.blocked.storageValue,
      );
      return const DeviceCommandExecutionResult(
        status: DeviceCommandStatus.executed,
        requiresLogout: true,
        wasWiped: false,
        message: 'Logout required',
      );
    case DeviceCommandType.wipeData:
      await performCryptoWipe(prefs: resolvedPrefs);
      await resolvedPrefs.setString(
        'ff_device_status',
        DeviceStatus.wiped.storageValue,
      );
      return const DeviceCommandExecutionResult(
        status: DeviceCommandStatus.executed,
        requiresLogout: true,
        wasWiped: true,
        message: 'Device wiped',
      );
  }
}

Future<void> registerCurrentDevice({
  required FirebaseFirestore firestore,
  required String companyId,
  required String userId,
  SharedPreferences? prefs,
}) async {
  final deviceId = await resolveCurrentDeviceId(prefs: prefs);
  await firestore.collection('devices').doc(deviceId).set(
        buildDevicePayload(
          companyId: companyId,
          deviceId: deviceId,
          userId: userId,
          status: DeviceStatus.active,
        ),
        SetOptions(merge: true),
      );
}

Future<List<Map<String, dynamic>>> fetchPendingDeviceCommands({
  required FirebaseFirestore firestore,
  required String companyId,
  SharedPreferences? prefs,
}) async {
  final deviceId = await resolveCurrentDeviceId(prefs: prefs);
  final snap = await firestore
      .collection('device_commands')
      .where('idCompany', isEqualTo: companyId)
      .where('device_id', isEqualTo: deviceId)
      .where('status', isEqualTo: DeviceCommandStatus.pending.storageValue)
      .get();
  return snap.docs
      .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
      .toList(growable: false);
}

Future<List<DeviceCommandExecutionResult>> processPendingDeviceCommands({
  required FirebaseFirestore firestore,
  required String companyId,
  SharedPreferences? prefs,
}) async {
  final pending = await fetchPendingDeviceCommands(
    firestore: firestore,
    companyId: companyId,
    prefs: prefs,
  );
  final results = <DeviceCommandExecutionResult>[];
  for (final command in pending) {
    final result = await executeDeviceCommand(
      command: command,
      prefs: prefs,
    );
    results.add(result);
    await firestore.collection('device_commands').doc(command['id']).set(
      {
        'status': result.status.storageValue,
        'executed_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'execution_message': result.message,
      },
      SetOptions(merge: true),
    );
    if (result.wasWiped) {
      final deviceId = (command['device_id'] ?? '').toString();
      if (deviceId.isNotEmpty) {
        await firestore.collection('devices').doc(deviceId).set(
          {
            'status': DeviceStatus.wiped.storageValue,
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    }
  }
  return results;
}

String _generateDeviceId() {
  final random = Random.secure();
  final milliseconds = DateTime.now().millisecondsSinceEpoch;
  final suffix = List.generate(
    8,
    (_) => random.nextInt(16).toRadixString(16),
  ).join();
  return 'device-$milliseconds-$suffix';
}
