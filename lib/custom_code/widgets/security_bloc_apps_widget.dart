// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'index.dart'; // Imports other custom widgets
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/custom_code/widgets/company_reload_mixin.dart';
import '/utils/device_management_support.dart';
import '/utils/effective_company_support.dart';
import '/utils/security_hash.dart';

class SecurityBlocAppsWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const SecurityBlocAppsWidget({
    super.key,
    this.width,
    this.height,
  });

  @override
  State<SecurityBlocAppsWidget> createState() => _SecurityBlocAppsWidgetState();
}

class _SecurityBlocAppsWidgetState extends State<SecurityBlocAppsWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  List<Map<String, dynamic>> _blocked = [];
  final _app = TextEditingController();
  final _reason = TextEditingController();
  final _currentPin = TextEditingController();
  final _newPin = TextEditingController();
  final _confirmPin = TextEditingController();
  bool _biometricEnabled = false;
  bool _autoLockEnabled = false;
  String _autoLockTime = '5';
  bool _changingPin = false;
  String _message = '';
  bool _temporaryEditingEnabled = false;
  DateTime? _temporaryEditingUntil;
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _commands = [];
  List<Map<String, dynamic>> _employees = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _app.dispose();
    _reason.dispose();
    _currentPin.dispose();
    _newPin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _blocked = [];
          _devices = [];
          _commands = [];
          _employees = [];
        });
        return;
      }
      final effectiveCompanyId = _effectiveCompanyId(user);

      final snap = await _firestore
          .collection('blocked_apps')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final secSnap = await _firestore
          .collection('security_settings')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .limit(1)
          .getCached();
      final deviceSnap = await _firestore
          .collection('devices')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .orderBy('updated_at', descending: true)
          .limit(20)
          .getCached();
      final commandSnap = await _firestore
          .collection('device_commands')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .orderBy('created_at', descending: true)
          .limit(30)
          .getCached();
      final employeeSnap = await _firestore
          .collection('employees')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final companySnap = await _firestore
          .collection('companies')
          .doc(effectiveCompanyId)
          .get(const GetOptions(source: Source.serverAndCache));

      if (secSnap.docs.isNotEmpty) {
        final raw = secSnap.docs.first.data();
        final data = raw is Map<String, dynamic>
            ? raw
            : Map<String, dynamic>.from(raw as Map);
        _biometricEnabled = data['biometricEnabled'] == true;
        _autoLockEnabled = data['autoLockEnabled'] == true;
        _autoLockTime = (data['autoLockTime'] ?? '5').toString();
      }
      final companyData = companySnap.data();
      if (companyData != null) {
        _temporaryEditingEnabled =
            companyData['temporary_editing_enabled'] == true ||
                companyData['temporaryEditingEnabled'] == true;
        _temporaryEditingUntil = _readDateTime(
          companyData['temporary_editing_until'] ??
              companyData['temporaryEditingUntil'],
        );
        if (_temporaryEditingUntil == null ||
            !_temporaryEditingUntil!.isAfter(DateTime.now())) {
          _temporaryEditingEnabled = false;
        }
      }

      setState(() {
        _blocked = snap.docs.map((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': d.id, ...data};
        }).toList();
        _devices = deviceSnap.docs.map((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': d.id, ...data};
        }).toList();
        _commands = commandSnap.docs.map((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': d.id, ...data};
        }).toList();
        _employees = employeeSnap.docs.map((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': d.id, ...data};
        }).toList()
          ..sort((a, b) => (a['name'] ?? '')
              .toString()
              .compareTo((b['name'] ?? '').toString()));
      });
    } catch (e) {
      debugPrint('Error loading blocked apps: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _effectiveCompanyId(User user) {
    return resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: user.uid,
    );
  }

  Future<void> _logSecurity({
    required String action,
    required String message,
    Map<String, dynamic> details = const <String, dynamic>{},
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final effectiveCompanyId = _effectiveCompanyId(user);
    await _firestore.collection('security_logs').add({
      'idCompany': effectiveCompanyId,
      'user_id': user.uid,
      'action': action,
      'message': message,
      'details': details,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      final dynamic raw = value;
      final converted = raw.toDate();
      if (converted is DateTime) return converted;
    } catch (_) {
      return DateTime.tryParse(value.toString());
    }
    return null;
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _addBlocked() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final effectiveCompanyId = _effectiveCompanyId(user);
    await _firestore.collection('blocked_apps').add({
      'app': _app.text.trim(),
      'reason': _reason.text.trim(),
      'idCompany': effectiveCompanyId,
      'user_id': user.uid,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('blocked_apps', effectiveCompanyId);
    await _logSecurity(
      action: 'blocked_app_added',
      message: 'Добавлена блокировка приложения',
      details: {'app': _app.text.trim(), 'reason': _reason.text.trim()},
    );
    _app.clear();
    _reason.clear();
    await _loadData();
  }

  Future<void> _saveSecuritySettings() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final effectiveCompanyId = _effectiveCompanyId(user);

    final secSnap = await _firestore
        .collection('security_settings')
        .where('idCompany', isEqualTo: effectiveCompanyId)
        .limit(1)
        .getCached();

    final data = {
      'biometricEnabled': _biometricEnabled,
      'autoLockEnabled': _autoLockEnabled,
      'autoLockTime': _autoLockTime,
      'updated_at': FieldValue.serverTimestamp(),
      'idCompany': effectiveCompanyId,
      'user_id': user.uid,
    };

    if (secSnap.docs.isEmpty) {
      await _firestore.collection('security_settings').add({
        ...data,
        'created_at': FieldValue.serverTimestamp(),
      });
    } else {
      await _firestore
          .collection('security_settings')
          .doc(secSnap.docs.first.id)
          .update(data);
    }
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('security_settings', effectiveCompanyId);
    await _logSecurity(
      action: 'security_settings_updated',
      message: 'Настройки безопасности сохранены',
    );
    setState(() => _message = 'Настройки безопасности сохранены');
  }

  Future<void> _setTemporaryEditing(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final effectiveCompanyId = _effectiveCompanyId(user);
    final until = enabled ? DateTime.now().add(const Duration(days: 30)) : null;
    final payload = {
      'temporary_editing_enabled': enabled,
      'temporaryEditingEnabled': enabled,
      'temporary_editing_until':
          until == null ? FieldValue.delete() : Timestamp.fromDate(until),
      'temporaryEditingUntil':
          until == null ? FieldValue.delete() : Timestamp.fromDate(until),
      'data_locked': !enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _firestore.collection('companies').doc(effectiveCompanyId).set(
          payload,
          SetOptions(merge: true),
        );
    await currentUserReference?.update({
      ...payload,
      'updated_at': FieldValue.serverTimestamp(),
    });
    await _firestore.collection('security_logs').add({
      'idCompany': effectiveCompanyId,
      'user_id': user.uid,
      'action':
          enabled ? 'temporary_editing_opened' : 'temporary_editing_closed',
      'message': enabled
          ? 'Редактирование документов открыто на 30 дней'
          : 'Ограничения редактирования возвращены',
      'temporary_editing_until':
          until == null ? null : Timestamp.fromDate(until),
      'created_at': FieldValue.serverTimestamp(),
    });
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('security_settings', effectiveCompanyId);
    setState(() {
      _temporaryEditingEnabled = enabled;
      _temporaryEditingUntil = until;
      _message = enabled
          ? 'Редактирование открыто до ${_formatDate(until!)}'
          : 'Ограничения редактирования включены';
    });
  }

  Future<void> _sendDeviceCommand(
    String deviceId,
    DeviceCommandType commandType,
  ) async {
    final user = _auth.currentUser;
    if (user == null || deviceId.trim().isEmpty) return;
    final effectiveCompanyId = _effectiveCompanyId(user);
    await _firestore.collection('device_commands').add(
          buildDeviceCommandPayload(
            companyId: effectiveCompanyId,
            deviceId: deviceId,
            issuedByUserId: user.uid,
            commandType: commandType,
          ),
        );
    final nextStatus = commandType == DeviceCommandType.wipeData
        ? DeviceStatus.wiped
        : DeviceStatus.blocked;
    await _firestore.collection('devices').doc(deviceId).set(
      {
        'status': nextStatus.storageValue,
        'blocked_by_user_id': user.uid,
        'blocked_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await _logSecurity(
      action: 'device_command_sent',
      message: 'Отправлена команда устройству',
      details: {
        'device_id': deviceId,
        'command_type': commandType.storageValue,
      },
    );
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('device_commands', effectiveCompanyId);
    setState(() => _message = 'Команда отправлена');
    await _loadData();
  }

  Future<void> _setEmployeeBlocked(
    Map<String, dynamic> employee,
    bool blocked,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final effectiveCompanyId = _effectiveCompanyId(user);
    final employeeId = (employee['id'] ?? '').toString().trim();
    final employeeUserId =
        (employee['user_id'] ?? employee['uid'] ?? employee['phone'] ?? '')
            .toString()
            .trim();
    if (employeeId.isEmpty) return;

    final patch = {
      'blocked': blocked,
      'bloc': blocked,
      'access_blocked': blocked,
      'blocked_at':
          blocked ? FieldValue.serverTimestamp() : FieldValue.delete(),
      'blocked_by_user_id': blocked ? user.uid : FieldValue.delete(),
      'updated_at': FieldValue.serverTimestamp(),
    };
    await _firestore.collection('employees').doc(employeeId).set(
          patch,
          SetOptions(merge: true),
        );
    if (employeeUserId.isNotEmpty) {
      await _firestore.collection('users').doc(employeeUserId).set(
        {
          'blocked': blocked,
          'bloc': blocked,
          'access_blocked': blocked,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      final employeeDevices = await _firestore
          .collection('devices')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .where('user_id', isEqualTo: employeeUserId)
          .getCached();
      final batch = _firestore.batch();
      for (final doc in employeeDevices.docs) {
        batch.set(
          doc.reference,
          {
            'status': blocked
                ? DeviceStatus.blocked.storageValue
                : DeviceStatus.active.storageValue,
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        if (blocked) {
          batch.set(
            _firestore.collection('device_commands').doc(),
            buildDeviceCommandPayload(
              companyId: effectiveCompanyId,
              deviceId: doc.id,
              issuedByUserId: user.uid,
              commandType: DeviceCommandType.forceLogout,
              reason: 'employee_blocked',
            ),
          );
        }
      }
      await batch.commit();
    }
    await _logSecurity(
      action: blocked ? 'employee_blocked' : 'employee_unblocked',
      message: blocked ? 'Сотрудник заблокирован' : 'Сотрудник разблокирован',
      details: {
        'employee_id': employeeId,
        'employee_user_id': employeeUserId,
        'employee_name': (employee['name'] ?? '').toString(),
      },
    );
    setState(() => _message =
        blocked ? 'Сотрудник заблокирован' : 'Сотрудник разблокирован');
    await _loadData();
  }

  Future<void> _changePin() async {
    if (_newPin.text.length != 4 || _confirmPin.text != _newPin.text) {
      setState(() => _message = 'PIN должен быть из 4 цифр и совпадать');
      return;
    }
    final user = _auth.currentUser;
    if (user == null) return;
    final effectiveCompanyId = _effectiveCompanyId(user);

    final pinSnap = await _firestore
        .collection('security_pins')
        .where('idCompany', isEqualTo: effectiveCompanyId)
        .where('user_id', isEqualTo: user.uid)
        .limit(1)
        .getCached();

    if (pinSnap.docs.isNotEmpty) {
      final raw = pinSnap.docs.first.data();
      final data = raw is Map<String, dynamic>
          ? raw
          : Map<String, dynamic>.from(raw as Map);
      final savedHash = (data['pin_hash'] ?? '').toString().trim();
      final legacyPin = (data['pin'] ?? '').toString().trim();
      final pinMatches = savedHash.isNotEmpty
          ? matchesSensitiveHash(_currentPin.text.trim(), savedHash)
          : legacyPin.isNotEmpty && _currentPin.text.trim() == legacyPin;
      if (!pinMatches) {
        setState(() => _message = 'Текущий PIN неверен');
        return;
      }
      await _firestore
          .collection('security_pins')
          .doc(pinSnap.docs.first.id)
          .update({
        'pin_hash': hashSensitiveValue(_newPin.text.trim()),
        'pin': FieldValue.delete(),
        'updated_at': FieldValue.serverTimestamp(),
        'pin_migrated_at': FieldValue.serverTimestamp(),
      });
    } else {
      await _firestore.collection('security_pins').add({
        'pin_hash': hashSensitiveValue(_newPin.text.trim()),
        'user_id': user.uid,
        'idCompany': effectiveCompanyId,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'pin_migrated_at': FieldValue.serverTimestamp(),
      });
    }

    FirestoreQueryCache.instance
        .invalidateCompanyCollection('security_pins', effectiveCompanyId);
    setState(() {
      _message = 'PIN-код обновлен';
      _changingPin = false;
      _currentPin.clear();
      _newPin.clear();
      _confirmPin.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!PermissionsHelper.has('security.block')) {
      return PermissionsHelper.noAccess();
    }
    return ResponsiveFrame(
      backgroundColor: const Color(0xFFF7F8FA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context)
                      .success
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: FlutterFlowTheme.of(context).success),
                ),
                child: Text(_message,
                    style: const TextStyle(color: Color(0xFF166534))),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context)
                        .warning
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.block, color: Color(0xFFF97316)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Блокировка приложений',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Список запрещенных приложений',
                        style: TextStyle(
                          fontSize: 13,
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: FlutterFlowTheme.of(context).alternate),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Безопасность',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _temporaryEditingEnabled
                          ? const Color(0xFFEFF6FF)
                          : FlutterFlowTheme.of(context).primaryBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _temporaryEditingEnabled
                            ? const Color(0xFF2563EB)
                            : FlutterFlowTheme.of(context).alternate,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Временное редактирование документов',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: FlutterFlowTheme.of(context).primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _temporaryEditingEnabled &&
                                  _temporaryEditingUntil != null
                              ? 'Открыто до ${_formatDate(_temporaryEditingUntil!)}'
                              : 'Ограничения редактирования включены',
                          style: TextStyle(
                            fontSize: 13,
                            color: FlutterFlowTheme.of(context).secondaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _temporaryEditingEnabled
                                  ? null
                                  : () => _setTemporaryEditing(true),
                              icon: const Icon(Icons.lock_open, size: 18),
                              label: const Text('Открыть на 30 дней'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _temporaryEditingEnabled
                                  ? () => _setTemporaryEditing(false)
                                  : null,
                              icon: const Icon(Icons.lock, size: 18),
                              label: const Text('Вернуть ограничения'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Биометрия'),
                    value: _biometricEnabled,
                    onChanged: (v) {
                      setState(() => _biometricEnabled = v);
                      _saveSecuritySettings();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Автоблокировка'),
                    value: _autoLockEnabled,
                    onChanged: (v) {
                      setState(() => _autoLockEnabled = v);
                      _saveSecuritySettings();
                    },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _autoLockTime,
                    decoration:
                        const InputDecoration(labelText: 'Время блокировки'),
                    items: const [
                      DropdownMenuItem(value: '1', child: Text('1 мин')),
                      DropdownMenuItem(value: '5', child: Text('5 мин')),
                      DropdownMenuItem(value: '10', child: Text('10 мин')),
                      DropdownMenuItem(value: '30', child: Text('30 мин')),
                    ],
                    onChanged: (v) {
                      setState(() => _autoLockTime = v ?? '5');
                      _saveSecuritySettings();
                    },
                  ),
                  const SizedBox(height: 8),
                  if (!_changingPin)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton(
                        onPressed: () => setState(() => _changingPin = true),
                        child: const Text('Изменить PIN'),
                      ),
                    )
                  else ...[
                    TextField(
                      controller: _currentPin,
                      decoration:
                          const InputDecoration(labelText: 'Текущий PIN'),
                    ),
                    TextField(
                      controller: _newPin,
                      decoration: const InputDecoration(labelText: 'Новый PIN'),
                    ),
                    TextField(
                      controller: _confirmPin,
                      decoration:
                          const InputDecoration(labelText: 'Повтор PIN'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _changePin,
                          child: const Text('Сохранить'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => setState(() => _changingPin = false),
                          child: const Text('Отмена'),
                        ),
                      ],
                    )
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: FlutterFlowTheme.of(context).alternate),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Сотрудники и доступ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (_employees.isEmpty)
                    Text(
                      'Сотрудники не найдены',
                      style: TextStyle(
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                    )
                  else
                    ..._employees.take(8).map((employee) {
                      final name = (employee['name'] ?? '-').toString();
                      final role = (employee['role_name'] ??
                              employee['role'] ??
                              'Роль не указана')
                          .toString();
                      final blocked = employee['blocked'] == true ||
                          employee['bloc'] == true ||
                          employee['access_blocked'] == true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$role • ${blocked ? 'заблокирован' : 'активен'}',
                                    style: TextStyle(
                                      color: blocked
                                          ? FlutterFlowTheme.of(context).error
                                          : FlutterFlowTheme.of(context)
                                              .secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () =>
                                  _setEmployeeBlocked(employee, !blocked),
                              child: Text(blocked ? 'Разблокировать' : 'Блок'),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: FlutterFlowTheme.of(context).alternate),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Устройства и команды',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (_devices.isEmpty)
                    Text(
                      'Устройства не зарегистрированы',
                      style: TextStyle(
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                    )
                  else
                    ..._devices.take(5).map((device) {
                      final deviceId =
                          (device['device_id'] ?? device['id'] ?? '')
                              .toString();
                      final status = deviceStatusFromValue(
                        (device['status'] ?? '').toString(),
                      );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deviceId.isEmpty ? '-' : deviceId,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text('Статус: ${status.storageValue}'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _sendDeviceCommand(
                                    deviceId,
                                    DeviceCommandType.lockApp,
                                  ),
                                  child: const Text('Lock'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _sendDeviceCommand(
                                    deviceId,
                                    DeviceCommandType.forceLogout,
                                  ),
                                  child: const Text('Logout'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _sendDeviceCommand(
                                    deviceId,
                                    DeviceCommandType.wipeData,
                                  ),
                                  child: const Text('Wipe'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  if (_commands.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Последние команды',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    ..._commands.take(5).map(
                          (command) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${command['command_type'] ?? ''} • ${command['status'] ?? ''}',
                            ),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _app,
                    decoration: const InputDecoration(labelText: 'Приложение'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _reason,
                    decoration: const InputDecoration(labelText: 'Причина'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addBlocked,
                  child: const Text('Добавить'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: FlutterFlowTheme.of(context).alternate),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Список блокировок',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _tableHeader(),
                        const Divider(height: 1),
                        Expanded(
                          child: _blocked.isEmpty
                              ? Center(
                                  child: Text(
                                    'Блокировок не найдено',
                                    style: TextStyle(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _blocked.length,
                                  itemBuilder: (context, index) {
                                    return _tableRow(_blocked[index]);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return Row(
      children: const [
        _HeaderCell('Приложение', flex: 2),
        _HeaderCell('Причина', flex: 4),
      ],
    );
  }

  Widget _tableRow(Map<String, dynamic> item) {
    final app = (item['app'] ?? '').toString();
    final reason = (item['reason'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: FlutterFlowTheme.of(context)
                    .alternate
                    .withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          _Cell(app.isEmpty ? '-' : app, flex: 2, bold: true),
          _Cell(reason.isEmpty ? '-' : reason, flex: 4),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;

  const _HeaderCell(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(text,
          style: TextStyle(
              fontSize: 12, color: FlutterFlowTheme.of(context).secondaryText)),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final int flex;
  final bool bold;

  const _Cell(this.text, {required this.flex, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          color: const Color(0xFF1F2A37),
        ),
      ),
    );
  }
}
