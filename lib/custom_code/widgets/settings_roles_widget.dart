// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'index.dart'; // Imports other custom widgets
import 'package:flutter/material.dart';
import '/custom_code/widgets/editing_helper.dart';
import '/utils/default_company_roles.dart';
import '/utils/permission_catalog.dart';
import '/utils/permission_tree_selector.dart';
import '/utils/role_assignment_support.dart';
import '/backend/api_requests/api_calls.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsRolesWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const SettingsRolesWidget({
    super.key,
    this.width,
    this.height,
  });

  @override
  State<SettingsRolesWidget> createState() => _SettingsRolesWidgetState();
}

class _CompanyPick {
  final String id;
  final String name;

  const _CompanyPick({required this.id, required this.name});
}

class _SettingsRolesWidgetState extends State<SettingsRolesWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  List<Map<String, dynamic>> _roles = [];
  List<_CompanyPick> _ownerCompanies = [];
  String _requestedCompanyId = '';
  String _loadedCompanyId = '';
  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  String get _companyId {
    final user = _auth.currentUser;
    final active = (currentUserDocument?.activeCompanyId ?? '').trim();
    if (active.isNotEmpty && active != '__all__') return active;
    final rawCompanyId = (currentUserDocument?.idCompany ?? '').trim();
    if (rawCompanyId.isNotEmpty && rawCompanyId != '__all__') {
      return rawCompanyId;
    }
    final ids = currentUserDocument?.companyIds ?? const [];
    for (final raw in ids) {
      final id = raw.toString().trim();
      if (id.isNotEmpty && id != '__all__') return id;
    }
    return user?.uid ?? '';
  }

  bool _looksLikeRole(Map<String, dynamic> data) {
    if (data['is_deleted'] == true) return false;
    final type = (data['type'] ?? '').toString().toLowerCase().trim();
    if (type == 'role_deleted' || type == 'deleted') return false;
    if (type == 'position') return false;
    if (type == 'role') return true;
    if (data['permissions'] is List) return true;
    if (data['allowed_company_ids'] is List) return true;
    return false;
  }

  String _roleNameKey(Map<String, dynamic> data) {
    final name = (data['name_key'] ?? data['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      return 'id:${(data['id'] ?? '').toString().trim()}';
    }
    return name.toLowerCase();
  }

  int _roleScore(Map<String, dynamic> data) {
    final permissions = normalizePermissionList(data['permissions']).length;
    final description =
        (data['description'] ?? '').toString().trim().isNotEmpty ? 1 : 0;
    return permissions * 10 + description;
  }

  bool _isDefaultRole(Map<String, dynamic> data) {
    if (_isSystemOwnerRole(data)) return true;
    final source = (data['source'] ?? '').toString().trim().toLowerCase();
    if (source != 'default_company_roles') return false;
    final defaultNames = kDefaultCompanyRoleTemplates
        .map((role) => role.name.trim().toLowerCase())
        .toSet();
    return defaultNames.contains(_roleNameKey(data));
  }

  List<Map<String, dynamic>> _dedupeRoles(Iterable<Map<String, dynamic>> rows) {
    final byName = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      if (!_looksLikeRole(row)) continue;
      final key = _roleNameKey(row);
      final current = byName[key];
      if (current == null || _roleScore(row) > _roleScore(current)) {
        byName[key] = row;
      }
    }
    final list = byName.values.toList()
      ..sort((a, b) {
        final aGroup = _isDefaultRole(a) ? 1 : 0;
        final bGroup = _isDefaultRole(b) ? 1 : 0;
        if (aGroup != bGroup) return aGroup.compareTo(bGroup);
        return (a['name'] ?? '')
            .toString()
            .compareTo((b['name'] ?? '').toString());
      });
    return list;
  }

  bool _looksLikeCompany(Map<String, dynamic> data) {
    if (data['ownerId'] != null) return true;
    if (data['members'] is List) return true;
    if (data['bin'] != null) return true;
    if (data['address'] != null) return true;
    return false;
  }

  bool _isAdminUser() {
    final data = currentUserDocument?.snapshotData ?? const {};
    final roleRaw = (data['role'] ?? '').toString().toLowerCase().trim();
    return (data['is_admin'] == true) ||
        (data['admin'] == true) ||
        roleRaw == 'admin' ||
        roleRaw == 'owner' ||
        roleRaw == 'business_owner' ||
        roleRaw == 'владелец';
  }

  bool _canManageRoleDefinitions() {
    final data = currentUserDocument?.snapshotData ?? const {};
    final roleRaw = (data['role'] ?? '').toString().toLowerCase().trim();
    return (data['is_admin'] == true) ||
        (data['admin'] == true) ||
        roleRaw == 'admin' ||
        roleRaw == 'super_admin' ||
        roleRaw == 'superadmin';
  }

  bool _isSystemOwnerRole(Map<String, dynamic> role) {
    final normalizedName = (role['name_key'] ?? role['name'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final roleId = (role['id'] ?? '').toString().trim().toLowerCase();
    final ownerDocPart =
        Uri.encodeComponent('владелец / директор').toLowerCase();
    return normalizedName == 'владелец / директор' ||
        normalizedName == 'владелец' ||
        normalizedName == 'owner' ||
        normalizedName == 'business_owner' ||
        (roleId.startsWith('default_role__') && roleId.contains(ownerDocPart));
  }

  List<String> _companyIdsForUser() {
    final ids = <String>{};
    final rawIds = currentUserDocument?.companyIds ?? const [];
    for (final raw in rawIds) {
      final id = raw.toString().trim();
      if (id.isNotEmpty && id != '__all__') ids.add(id);
    }
    final primary = (currentUserDocument?.idCompany ?? '').trim();
    if (primary.isNotEmpty && primary != '__all__') ids.add(primary);
    final active = (currentUserDocument?.activeCompanyId ?? '').trim();
    if (active.isNotEmpty && active != '__all__') ids.add(active);
    return ids.toList();
  }

  Iterable<List<String>> _chunkIds(List<String> ids, int size) sync* {
    if (ids.isEmpty) return;
    for (var i = 0; i < ids.length; i += size) {
      final end = (i + size) > ids.length ? ids.length : i + size;
      yield ids.sublist(i, end);
    }
  }

  void _reloadWhenCompanyChanged() {
    final companyId = _companyId;
    if (companyId.isEmpty || companyId == _requestedCompanyId) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || companyId != _companyId) return;
      _loadAll(companyIdOverride: companyId);
    });
  }

  Future<void> _loadAll({String? companyIdOverride}) async {
    final requestId = ++_loadRequestId;
    final companyId = (companyIdOverride ?? _companyId).trim();
    _requestedCompanyId = companyId;
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (!mounted || requestId != _loadRequestId) return;
        setState(() {
          _roles = [];
          _loadedCompanyId = companyId;
        });
        return;
      }

      if (companyId.isNotEmpty) {
        await ensureDefaultCompanyRoles(
          firestore: _firestore,
          companyId: companyId,
          userId: currentUserUid,
          seedOnlyWhenNoRoles: false,
        );
        FirestoreQueryCache.instance
            .invalidateCompanyCollection('roles', companyId);
      }

      final rolesSnap = await _firestore
          .collection('roles')
          .where('idCompany', isEqualTo: companyId)
          .get(const GetOptions(source: Source.serverAndCache));

      final ownerCompanies = <_CompanyPick>[];
      final companyIds = _companyIdsForUser();
      if (companyIds.isNotEmpty) {
        for (final chunk in _chunkIds(companyIds, 10)) {
          final byIdsSnap = await _firestore
              .collection('companies')
              .where(FieldPath.documentId, whereIn: chunk)
              .getCached(key: 'companies/by_ids/${chunk.join(",")}');
          for (final doc in byIdsSnap.docs) {
            final raw = doc.data();
            final data = raw is Map<String, dynamic>
                ? raw
                : Map<String, dynamic>.from(raw as Map);
            if (!_looksLikeCompany(data)) continue;
            final name = (data['name'] ?? 'Компания').toString();
            ownerCompanies.add(_CompanyPick(id: doc.id, name: name));
          }
        }
      }
      if (ownerCompanies.isEmpty) {
        final ownerCompaniesSnap = await _firestore
            .collection('companies')
            .where('ownerId', isEqualTo: user.uid)
            .getCached(key: 'companies/owner/${user.uid}');
        final companyDocs = ownerCompaniesSnap.docs.isNotEmpty
            ? ownerCompaniesSnap.docs
            : (await _firestore
                    .collection('companies')
                    .where('members', arrayContains: user.uid)
                    .getCached(key: 'companies/members/${user.uid}'))
                .docs;
        for (final doc in companyDocs) {
          final raw = doc.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          if (!_looksLikeCompany(data)) continue;
          final name = (data['name'] ?? 'Компания').toString();
          ownerCompanies.add(_CompanyPick(id: doc.id, name: name));
        }
      }

      if (!mounted || requestId != _loadRequestId || companyId != _companyId) {
        return;
      }
      setState(() {
        _roles = _dedupeRoles(rolesSnap.docs.map((d) {
          final raw = d.data();
          final data = Map<String, dynamic>.from(raw as Map);
          return {'id': d.id, ...data};
        }));
        _ownerCompanies = ownerCompanies;
        _loadedCompanyId = companyId;
      });
    } catch (e) {
      debugPrint('Error loading roles/users: $e');
    } finally {
      if (mounted && requestId == _loadRequestId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateRole({
    required String roleId,
    required String name,
    required String description,
    required Set<String> permissions,
    required List<String> allowedCompanyIds,
  }) async {
    final current = _roles.firstWhere(
      (item) => (item['id'] ?? '').toString() == roleId,
      orElse: () => const <String, dynamic>{},
    );
    if (_isSystemOwnerRole(current)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Роль владельца нельзя редактировать.')),
      );
      return;
    }
    final companyId = _companyId;
    final roleName = name.trim();
    if (roleName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите название роли.')),
      );
      return;
    }
    final companyIds = _normalizeSelectedRoleCompanies(allowedCompanyIds);
    await _firestore.collection('roles').doc(roleId).update({
      'type': 'role',
      'name': roleName,
      'name_key': roleName.toLowerCase(),
      'description': description.trim(),
      'permissions': permissions.toList(),
      'allowed_company_ids': companyIds,
      'idCompany': companyId,
      'source': 'manual',
      'updated_at': FieldValue.serverTimestamp(),
    });
    await propagateRoleSnapshotToAssignments(
      firestore: _firestore,
      companyId: companyId,
      roleId: roleId,
      roleData: <String, dynamic>{
        'id': roleId,
        'name': roleName,
        'role_name': roleName,
        'permissions': permissions.toList(),
        'allowed_company_ids': companyIds,
      },
    );
    await _syncRoleToCompanies(
      sourceRoleId: roleId,
      name: roleName,
      description: description,
      permissions: permissions,
      companyIds: companyIds,
    );
    for (final id in companyIds) {
      FirestoreQueryCache.instance.invalidateCompanyCollection('roles', id);
    }
    await _loadAll();
  }

  Future<void> _createRole({
    required String name,
    required String description,
    required Set<String> permissions,
    required List<String> allowedCompanyIds,
  }) async {
    final companyId = _companyId;
    final roleName = name.trim();
    if (companyId.isEmpty || roleName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите название роли.')),
      );
      return;
    }
    final companyIds = _normalizeSelectedRoleCompanies(allowedCompanyIds);
    await _syncRoleToCompanies(
      name: roleName,
      description: description,
      permissions: permissions,
      companyIds: companyIds,
    );
    for (final id in companyIds) {
      FirestoreQueryCache.instance.invalidateCompanyCollection('roles', id);
    }
    await _loadAll();
  }

  List<String> _normalizeSelectedRoleCompanies(List<String> rawIds) {
    final selected = rawIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && id != '__all__')
        .toSet();
    if (selected.isEmpty && _companyId.isNotEmpty) selected.add(_companyId);
    return selected.toList()..sort();
  }

  Future<void> _syncRoleToCompanies({
    String? sourceRoleId,
    required String name,
    required String description,
    required Set<String> permissions,
    required List<String> companyIds,
  }) async {
    final roleName = name.trim();
    final nameKey = roleName.toLowerCase();
    for (final targetCompanyId in companyIds) {
      if (targetCompanyId.isEmpty) continue;
      final baseData = {
        'type': 'role',
        'name': roleName,
        'description': description.trim(),
        'permissions': permissions.toList(),
        'allowed_company_ids': companyIds,
        'idCompany': targetCompanyId,
        'user_id': currentUserUid,
        'name_key': nameKey,
        'source': 'manual',
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (sourceRoleId != null && targetCompanyId == _companyId) {
        continue;
      }

      final existing = await _firestore
          .collection('roles')
          .where('idCompany', isEqualTo: targetCompanyId)
          .where('name_key', isEqualTo: nameKey)
          .limit(1)
          .get(const GetOptions(source: Source.serverAndCache));

      if (existing.docs.isNotEmpty) {
        final doc = existing.docs.first;
        await doc.reference.set(baseData, SetOptions(merge: true));
        await propagateRoleSnapshotToAssignments(
          firestore: _firestore,
          companyId: targetCompanyId,
          roleId: doc.id,
          roleData: <String, dynamic>{
            'id': doc.id,
            'name': roleName,
            'role_name': roleName,
            'permissions': permissions.toList(),
            'allowed_company_ids': companyIds,
          },
        );
      } else {
        final ref = await _firestore.collection('roles').add({
          ...baseData,
          'created_at': FieldValue.serverTimestamp(),
        });
        await propagateRoleSnapshotToAssignments(
          firestore: _firestore,
          companyId: targetCompanyId,
          roleId: ref.id,
          roleData: <String, dynamic>{
            'id': ref.id,
            'name': roleName,
            'role_name': roleName,
            'permissions': permissions.toList(),
            'allowed_company_ids': companyIds,
          },
        );
      }
    }
  }

  Future<void> _handleAddRole() async {
    final result = await _showRoleDialog();
    if (result == null) return;
    await _createRole(
      name: result.name,
      description: result.description,
      permissions: result.permissions,
      allowedCompanyIds: result.companyIds.toList(),
    );
  }

  Future<void> _deleteRole(String roleId) async {
    if (!EditingHelper.guardEdit(context)) return;
    final current = _roles.firstWhere(
      (item) => (item['id'] ?? '').toString() == roleId,
      orElse: () => const <String, dynamic>{},
    );
    if (_isSystemOwnerRole(current)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Роль владельца нельзя удалить.')),
      );
      return;
    }
    final companyId = _companyId;
    await _firestore.collection('roles').doc(roleId).set({
      'type': 'role_deleted',
      'is_deleted': true,
      'deleted_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('roles', companyId);
    await _loadAll();
  }

  Future<void> _assignRole(String userId, String? roleId) async {
    final companyId = _companyId;
    final role = _roles.firstWhere(
      (r) => r['id'] == roleId,
      orElse: () => {},
    );
    final perms = normalizePermissionList(role['permissions']);
    final allowedCompanyIds = normalizeRoleCompanyIds(
      role['allowed_company_ids'],
      fallbackCompanyId: companyId,
    );
    final isSelf = userId == currentUserUid;
    if (isSelf && !_isAdminUser()) {
      if (perms.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Нельзя назначить себе роль без прав.'),
            ),
          );
        }
        return;
      }
      if (!perms.contains('settings.roles')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Эта роль не дает доступ к разделу Роли. Назначить себе нельзя.',
              ),
            ),
          );
        }
        return;
      }
    }
    final userRef = _firestore.collection('users').doc(userId);
    final update = buildUserRoleAssignmentPatch(
      roleData: <String, dynamic>{
        ...role,
        'id': roleId,
        'permissions': perms,
        'allowed_company_ids': allowedCompanyIds,
      },
      fallbackCompanyId: companyId,
    );
    await userRef.update(update);
    if (allowedCompanyIds.isNotEmpty) {
      for (final cid in allowedCompanyIds) {
        await _firestore.collection('companies').doc(cid).update({
          'members': FieldValue.arrayUnion([userId]),
        });
      }
    }
    final employees = await _firestore
        .collection('employees')
        .where('idCompany', isEqualTo: companyId)
        .where('user_id', isEqualTo: userId)
        .get();
    if (employees.docs.isNotEmpty) {
      final batch = _firestore.batch();
      final employeePatch = buildPositionSnapshot(
        roleData: <String, dynamic>{
          ...role,
          'id': roleId,
          'permissions': perms,
          'allowed_company_ids': allowedCompanyIds,
        },
        fallbackCompanyId: companyId,
      );
      for (final doc in employees.docs) {
        batch.update(doc.reference, {
          ...employeePatch,
          'role': (employeePatch['role_name'] ?? '').toString(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('users', companyId);
    await _loadAll();
  }

  bool _userMatchesRole(Map<String, dynamic> user, Map<String, dynamic> role) {
    final roleId = (role['id'] ?? '').toString().trim();
    final roleName = (role['name'] ?? '').toString().trim().toLowerCase();
    final userRoleId = (user['role_id'] ?? '').toString().trim();
    final userRoleName = (user['role_name'] ??
            user['role'] ??
            user['position'] ??
            user['position_name'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    if (roleId.isNotEmpty && userRoleId == roleId) return true;
    if (roleName.isEmpty || userRoleName.isEmpty) return false;
    if (userRoleName == roleName) return true;
    return _roleAliases(roleName).contains(userRoleName);
  }

  Set<String> _roleAliases(String roleName) {
    switch (roleName.trim().toLowerCase()) {
      case 'владелец / директор':
        return {'владелец', 'директор'};
      case 'закупщик / категорийный менеджер':
        return {'закупщик', 'категорийный менеджер', 'менеджер по закупу'};
      case 'продавец / менеджер по продажам':
        return {'продавец', 'менеджер по продажам'};
      case 'аналитик / финансовый директор':
        return {'аналитик', 'финансовый аналитик', 'финансовый директор'};
      case 'hr / оргструктура':
        return {'hr', 'эйчар', 'оргструктура'};
    }
    return const <String>{};
  }

  Future<List<Map<String, dynamic>>> _loadUsersForRole(
    Map<String, dynamic> role,
  ) async {
    final companyId = _companyId;
    if (companyId.isEmpty) return const <Map<String, dynamic>>[];

    final merged = <String, Map<String, dynamic>>{};
    final primarySnap = await _firestore
        .collection('users')
        .where('idCompany', isEqualTo: companyId)
        .get(const GetOptions(source: Source.serverAndCache));
    final memberSnap = await _firestore
        .collection('users')
        .where('companyIds', arrayContains: companyId)
        .get(const GetOptions(source: Source.serverAndCache));

    for (final doc in [...primarySnap.docs, ...memberSnap.docs]) {
      final data = doc.data();
      final user = {'id': doc.id, '_source': 'users', ...data};
      if (_userMatchesRole(user, role)) {
        merged[doc.id] = user;
      }
    }

    final employeesSnap = await _firestore
        .collection('employees')
        .where('idCompany', isEqualTo: companyId)
        .get(const GetOptions(source: Source.serverAndCache));
    for (final doc in employeesSnap.docs) {
      final data = doc.data();
      final employee = {
        'id': doc.id,
        '_source': 'employees',
        'display_name': data['name'] ?? data['display_name'],
        ...data,
      };
      if (!_userMatchesRole(employee, role)) continue;
      final userId = (employee['user_id'] ?? '').toString().trim();
      final key = userId.isNotEmpty && merged.containsKey(userId)
          ? userId
          : 'employee:${doc.id}';
      merged[key] = {
        ...?merged[key],
        ...employee,
      };
    }

    final users = merged.values.toList()
      ..sort((a, b) {
        final aName =
            (a['display_name'] ?? a['name'] ?? a['phone_number'] ?? '')
                .toString()
                .toLowerCase();
        final bName =
            (b['display_name'] ?? b['name'] ?? b['phone_number'] ?? '')
                .toString()
                .toLowerCase();
        return aName.compareTo(bName);
      });
    return users;
  }

  Future<void> _showRoleUsersDialog(Map<String, dynamic> role) async {
    final roleName = (role['name'] ?? 'Роль').toString();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Пользователи роли: $roleName'),
          content: SizedBox(
            width: 560,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadUsersForRole(role),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('Не удалось загрузить пользователей.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final users = snapshot.data ?? const <Map<String, dynamic>>[];
                if (users.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'В этой роли пока нет пользователей.',
                      style: TextStyle(
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                    ),
                  );
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: users.length,
                    separatorBuilder: (_, __) => Divider(
                      color: FlutterFlowTheme.of(context).alternate,
                    ),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final name = (user['display_name'] ?? user['name'] ?? '')
                          .toString()
                          .trim();
                      final phone =
                          (user['phone_number'] ?? user['phoneNumber'] ?? '')
                              .toString()
                              .trim();
                      final email = (user['email'] ?? '').toString().trim();
                      final department =
                          (user['department'] ?? '').toString().trim();
                      final source = (user['_source'] ?? '').toString();
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              FlutterFlowTheme.of(context).primaryBackground,
                          child: Icon(
                            Icons.person_outline,
                            color: FlutterFlowTheme.of(context).primaryText,
                            size: 20,
                          ),
                        ),
                        title: Text(name.isEmpty ? 'Пользователь' : name),
                        subtitle: Text(
                          [
                            if (phone.isNotEmpty) phone,
                            if (email.isNotEmpty) email,
                            if (department.isNotEmpty) department,
                            if (source == 'employees') 'сотрудник',
                          ].join(' · '),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  String _companyNameById(String companyId) {
    for (final company in _ownerCompanies) {
      if (company.id == companyId) return company.name;
    }
    return companyId.isEmpty ? 'Компания' : companyId;
  }

  Future<void> _showAddUserDialog() async {
    if (!EditingHelper.guardEdit(context)) return;
    if (_companyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось определить компанию.')),
      );
      return;
    }
    if (_roles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала должны быть доступны роли.')),
      );
      return;
    }

    final result = await showDialog<_NewRoleUserResult>(
      context: context,
      builder: (context) => _AddRoleUserDialog(
        roles: _roles,
        companyName: _companyNameById(_companyId),
      ),
    );
    if (result == null) return;

    final role = _roles.firstWhere(
      (item) => (item['id'] ?? '').toString() == result.roleId,
      orElse: () => <String, dynamic>{},
    );
    if (role.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выбранная роль не найдена.')),
      );
      return;
    }

    final response = await TokenCall.call(
      phone: result.phone,
      password: result.password,
      mode: 'signup',
      role: 'emp',
      companyId: _companyId,
      displayName: result.name,
      roleId: result.roleId,
      roleName: (role['name'] ?? '').toString(),
      rolePermissions: normalizePermissionList(role['permissions']),
      roleAllowedCompanyIds: normalizeRoleCompanyIds(
        role['allowed_company_ids'],
        fallbackCompanyId: _companyId,
      ),
      position: result.position,
      department: result.department,
    );

    final body = response.jsonBody;
    final errorCode =
        body is Map<String, dynamic> ? (body['error'] ?? '').toString() : '';
    if (!response.succeeded) {
      var message = 'Не удалось создать пользователя.';
      if (errorCode == 'account_already_exists') {
        message = 'Аккаунт с таким номером уже существует.';
      } else if (errorCode == 'company_id_is_required') {
        message = 'Не удалось определить компанию сотрудника.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    FirestoreQueryCache.instance
        .invalidateCompanyCollection('users', _companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('employees', _companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('companies', _companyId);
    await _loadAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Пользователь "${result.name}" добавлен в ${_companyNameById(_companyId)}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!PermissionsHelper.has('settings.roles')) {
      return PermissionsHelper.noAccess();
    }
    _reloadWhenCompanyChanged();
    return ResponsiveFrame(
      backgroundColor: const Color(0xFFF7F8FA),
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).accent1,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.admin_panel_settings_outlined,
                        color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Роли и доступы',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: FlutterFlowTheme.of(context).primaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Роли и пользователи',
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: TabBar(
                labelColor: Color(0xFF2563EB),
                unselectedLabelColor: Color(0xFF6B7280),
                indicatorColor: Color(0xFF2563EB),
                tabs: [
                  Tab(text: 'Роли'),
                  Tab(text: 'Пользователи'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _rolesTab(),
                        _usersTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rolesTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FlutterFlowTheme.of(context).alternate),
            ),
            child: const Text(
              'Роли подгружаются из админских шаблонов. Их можно редактировать и добавлять новые роли для компании.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF4B5563),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Стандартные роли можно менять. Новые роли добавляются вручную.',
                  style: TextStyle(
                    fontSize: 13,
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _roles.isEmpty
                ? Center(
                    child: Text(
                      'Роли для компании не настроены.',
                      style: TextStyle(
                          color: FlutterFlowTheme.of(context).secondaryText),
                    ),
                  )
                : ListView.builder(
                    itemCount: _roles.length,
                    itemBuilder: (context, index) {
                      final role = _roles[index];
                      return _roleCard(role);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _roleCard(Map<String, dynamic> role) {
    final name = (role['name'] ?? '').toString();
    final desc = (role['description'] ?? '').toString();
    final perms =
        (role['permissions'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final roleCompanyIds = normalizeRoleCompanyIds(
      role['allowed_company_ids'],
      fallbackCompanyId: (role['idCompany'] ?? _companyId).toString(),
    ).toSet();
    final isOwnerRole = _isSystemOwnerRole(role);
    final canEditRole = EditingHelper.canEditExisting() && !isOwnerRole;
    return InkWell(
      onTap: () => _showRoleUsersDialog(role),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FlutterFlowTheme.of(context).alternate),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name.isEmpty ? 'Без названия' : name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Показать пользователей этой роли',
                      child: IconButton(
                        onPressed: () => _showRoleUsersDialog(role),
                        icon: const Icon(Icons.people_outline, size: 20),
                      ),
                    ),
                    if (isOwnerRole)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Системная роль',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                    if (canEditRole)
                      TextButton(
                        onPressed: () async {
                          if (!EditingHelper.guardEdit(context)) return;
                          final result = await _showRoleDialog(
                            existingName: name,
                            existingDesc: desc,
                            existingPerms: perms.toSet(),
                            existingCompanyIds: roleCompanyIds,
                          );
                          if (result == null) return;
                          await _updateRole(
                            roleId: role['id'],
                            name: result.name,
                            description: result.description,
                            permissions: result.permissions,
                            allowedCompanyIds: result.companyIds.toList(),
                          );
                        },
                        child: const Text('Редактировать'),
                      ),
                    if (canEditRole)
                      TextButton(
                        onPressed: () => _deleteRole(role['id']),
                        child: const Text(
                          'Удалить',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(desc,
                      style: TextStyle(
                          color: FlutterFlowTheme.of(context).secondaryText)),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: perms
                      .take(8)
                      .map((p) => _pill(_permissionLabel(p)))
                      .toList(
                        growable: false,
                      ),
                ),
                if (perms.length > 8)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Еще ${perms.length - 8} разрешений',
                        style: TextStyle(
                            color: FlutterFlowTheme.of(context).secondaryText,
                            fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _usersTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FlutterFlowTheme.of(context).alternate),
            ),
            child: const Text(
              'Здесь можно добавлять сотрудников компании, назначать им роли и давать доступ к работе в программе.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF4B5563),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Добавляйте сотрудников с логином, паролем и ролью для текущей компании.',
                  style: TextStyle(
                    fontSize: 13,
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _showAddUserDialog,
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Добавить пользователя'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .where('idCompany', isEqualTo: _companyId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Ошибка загрузки пользователей',
                      style: TextStyle(
                          color: FlutterFlowTheme.of(context).secondaryText),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Пользователи не найдены',
                      style: TextStyle(
                          color: FlutterFlowTheme.of(context).secondaryText),
                    ),
                  );
                }
                final users = docs.map((d) {
                  final raw = d.data();
                  final data = raw is Map<String, dynamic>
                      ? raw
                      : Map<String, dynamic>.from(raw as Map);
                  return {'id': d.id, ...data};
                }).toList();
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return _userRow(user);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _userRow(Map<String, dynamic> user) {
    final name = (user['display_name'] ?? user['name'] ?? '').toString();
    final email = (user['email'] ?? '').toString();
    final roleId = (user['role_id'] ?? '').toString();
    final roleName = (user['role_name'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Пользователь' : name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(email,
                    style: TextStyle(
                        color: FlutterFlowTheme.of(context).secondaryText)),
                if (roleName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Роль: $roleName',
                      style: TextStyle(
                          color: FlutterFlowTheme.of(context).secondaryText)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String?>(
            value: roleId.isEmpty ? null : roleId,
            hint: const Text('Роль'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Без роли')),
              ..._roles.map((r) => DropdownMenuItem(
                    value: r['id'],
                    child: Text((r['name'] ?? 'Роль').toString()),
                  ))
            ],
            onChanged: (val) => _assignRole(user['id'], val),
          ),
        ],
      ),
    );
  }

  String _permissionLabel(String key) {
    return permissionLabel(key);
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11)),
    );
  }

  Future<_RoleDialogResult?> _showRoleDialog({
    String? existingName,
    String? existingDesc,
    Set<String>? existingPerms,
    Set<String>? existingCompanyIds,
  }) async {
    final selected = existingPerms ?? <String>{};
    final initialCompanyIds =
        existingCompanyIds ?? (_companyId.isEmpty ? <String>{} : {_companyId});
    return showDialog<_RoleDialogResult>(
      context: context,
      builder: (context) => _PermissionsDialog(
        title: existingName == null ? 'Роль: доступы' : 'Изменить доступы',
        nameLabel: 'Название роли',
        descriptionLabel: 'Описание',
        initialName: existingName ?? '',
        initialDescription: existingDesc ?? '',
        initialSelected: selected,
        companyLabel: 'Компании, где используется роль',
        companyOptions: _ownerCompanies,
        initialCompanyIds: initialCompanyIds,
      ),
    );
  }
}

class _RoleDialogResult {
  final String name;
  final String description;
  final Set<String> permissions;
  final Set<String> companyIds;

  _RoleDialogResult(
    this.name,
    this.description,
    this.permissions,
    this.companyIds,
  );
}

class _NewRoleUserResult {
  final String name;
  final String phone;
  final String password;
  final String roleId;
  final String position;
  final String department;

  const _NewRoleUserResult({
    required this.name,
    required this.phone,
    required this.password,
    required this.roleId,
    required this.position,
    required this.department,
  });
}

class _PermissionsDialog extends StatefulWidget {
  final String title;
  final String? nameLabel;
  final String? descriptionLabel;
  final String? initialName;
  final String? initialDescription;
  final Set<String> initialSelected;
  final String? companyLabel;
  final List<_CompanyPick>? companyOptions;
  final Set<String>? initialCompanyIds;

  const _PermissionsDialog({
    required this.title,
    this.nameLabel,
    this.descriptionLabel,
    this.initialName,
    this.initialDescription,
    required this.initialSelected,
    this.companyLabel,
    this.companyOptions,
    this.initialCompanyIds,
  });

  @override
  State<_PermissionsDialog> createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends State<_PermissionsDialog> {
  late Set<String> _selected;
  late Set<String> _selectedCompanies;
  late TextEditingController _name;
  late TextEditingController _desc;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelected);
    final defaultCompanies = widget.companyOptions
            ?.map((e) => e.id)
            .where((e) => e.isNotEmpty)
            .toSet() ??
        <String>{};
    _selectedCompanies = Set<String>.from(
      widget.initialCompanyIds == null || widget.initialCompanyIds!.isEmpty
          ? defaultCompanies
          : widget.initialCompanyIds!,
    );
    _name = TextEditingController(text: widget.initialName ?? '');
    _desc = TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 760,
        child: ListView(
          shrinkWrap: true,
          children: [
            if (widget.nameLabel != null) ...[
              TextField(
                controller: _name,
                decoration: InputDecoration(labelText: widget.nameLabel),
              ),
              const SizedBox(height: 8),
            ],
            if (widget.descriptionLabel != null) ...[
              TextField(
                controller: _desc,
                decoration: InputDecoration(labelText: widget.descriptionLabel),
              ),
              const SizedBox(height: 8),
            ],
            if (widget.companyOptions != null &&
                widget.companyOptions!.isNotEmpty) ...[
              Text(
                widget.companyLabel ?? 'Компании',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.companyOptions!.map((company) {
                  final selected = _selectedCompanies.contains(company.id);
                  return FilterChip(
                    label: Text(company.name),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedCompanies.add(company.id);
                        } else {
                          _selectedCompanies.remove(company.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: FlutterFlowTheme.of(context).alternate),
              ),
              child: const Text(
                'Права собраны по логике меню пользователя: сначала основной раздел, внутри него подразделы, а внутри них отдельные функции и кнопки.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                ),
              ),
            ),
            const SizedBox(height: 12),
            PermissionTreeSelector(
              selected: _selected,
              onChanged: (value) => setState(() => _selected = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              _RoleDialogResult(
                _name.text,
                _desc.text,
                _selected,
                _selectedCompanies,
              ),
            );
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _AddRoleUserDialog extends StatefulWidget {
  final List<Map<String, dynamic>> roles;
  final String companyName;

  const _AddRoleUserDialog({
    required this.roles,
    required this.companyName,
  });

  @override
  State<_AddRoleUserDialog> createState() => _AddRoleUserDialogState();
}

class _AddRoleUserDialogState extends State<_AddRoleUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _password;
  late final TextEditingController _position;
  late final TextEditingController _department;
  String? _roleId;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController();
    _password = TextEditingController();
    _position = TextEditingController();
    _department = TextEditingController();
    if (widget.roles.isNotEmpty) {
      _roleId = (widget.roles.first['id'] ?? '').toString();
      _position.text = (widget.roles.first['name'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    _position.dispose();
    _department.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить пользователя'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Сотрудник будет добавлен в компанию: ${widget.companyName}',
                  style: TextStyle(
                    fontSize: 13,
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  decoration:
                      const InputDecoration(labelText: 'Имя сотрудника'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Введите имя сотрудника'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Номер телефона'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Введите номер телефона'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Пароль'),
                  validator: (value) => (value ?? '').trim().length < 6
                      ? 'Минимум 6 символов'
                      : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _roleId,
                  decoration: const InputDecoration(labelText: 'Роль'),
                  items: widget.roles
                      .map(
                        (role) => DropdownMenuItem<String>(
                          value: (role['id'] ?? '').toString(),
                          child: Text((role['name'] ?? 'Роль').toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _roleId = value;
                    final role = widget.roles.firstWhere(
                      (item) => (item['id'] ?? '').toString() == value,
                      orElse: () => const <String, dynamic>{},
                    );
                    final roleName = (role['name'] ?? '').toString();
                    if (roleName.isNotEmpty) {
                      _position.text = roleName;
                    }
                  }),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Выберите роль' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _position,
                  decoration: const InputDecoration(
                    labelText: 'Должность',
                    hintText: 'Например, Бухгалтер',
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Введите должность' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _department,
                  decoration: const InputDecoration(
                    labelText: 'Отдел',
                    hintText: 'Например, Бухгалтерия',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              _NewRoleUserResult(
                name: _name.text.trim(),
                phone: _phone.text.trim(),
                password: _password.text.trim(),
                roleId: (_roleId ?? '').trim(),
                position: _position.text.trim(),
                department: _department.text.trim(),
              ),
            );
          },
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}
