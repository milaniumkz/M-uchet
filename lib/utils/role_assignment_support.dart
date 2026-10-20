import 'package:cloud_firestore/cloud_firestore.dart';

List<String> normalizeRoleCompanyIds(
  dynamic raw, {
  String fallbackCompanyId = '',
}) {
  final ids = <String>{};
  if (raw is List) {
    for (final item in raw) {
      final value = item.toString().trim();
      if (value.isNotEmpty) {
        ids.add(value);
      }
    }
  }
  final fallback = fallbackCompanyId.trim();
  if (fallback.isNotEmpty) {
    ids.add(fallback);
  }
  final list = ids.toList()..sort();
  return list;
}

List<String> normalizePermissionList(dynamic raw) {
  if (raw is! List) return const <String>[];
  return raw
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
}

Map<String, dynamic> fundingRequestPermissionFlags(List<String> permissions) {
  final set = permissions.toSet();
  return {
    'can_submit_funding_request': set.contains('funding_requests.create'),
    'can_responsible_sign_funding_request':
        set.contains('funding_requests.responsible_sign'),
    'can_approve_funding_request': set.contains('funding_requests.approve'),
    'can_final_approve_funding_request':
        set.contains('funding_requests.final_approve'),
    'can_pay_funding_request': set.contains('funding_requests.pay'),
    'can_edit_money_data': set.contains('scheta.edit') ||
        set.contains('tranzaction.edit') ||
        set.contains('money.company_expenses'),
    'can_delete_money_data':
        set.contains('scheta.delete') || set.contains('tranzaction.delete'),
  };
}

Map<String, dynamic> buildRoleSnapshot({
  required Map<String, dynamic> roleData,
  required String fallbackCompanyId,
}) {
  final roleId =
      (roleData['role_id'] ?? roleData['id'] ?? '').toString().trim();
  final roleName =
      (roleData['role_name'] ?? roleData['name'] ?? '').toString().trim();
  final permissions = normalizePermissionList(
    roleData['role_permissions'] ?? roleData['permissions'],
  );
  final allowedCompanyIds = normalizeRoleCompanyIds(
    roleData['allowed_company_ids'] ?? roleData['role_allowed_company_ids'],
    fallbackCompanyId: fallbackCompanyId,
  );

  return <String, dynamic>{
    'role_id': roleId,
    'role_name': roleName,
    'role_permissions': permissions,
    'role_allowed_company_ids': allowedCompanyIds,
    ...fundingRequestPermissionFlags(permissions),
  };
}

Map<String, dynamic> buildUserRoleAssignmentPatch({
  required Map<String, dynamic> roleData,
  required String fallbackCompanyId,
}) {
  final snapshot = buildRoleSnapshot(
    roleData: roleData,
    fallbackCompanyId: fallbackCompanyId,
  );
  final allowedCompanyIds = (snapshot['role_allowed_company_ids'] as List)
      .map((e) => e.toString())
      .toList();

  final update = <String, dynamic>{
    ...snapshot,
    'updated_at': FieldValue.serverTimestamp(),
  };
  if (allowedCompanyIds.isNotEmpty) {
    update['companyIds'] = allowedCompanyIds;
    update['activeCompanyId'] = allowedCompanyIds.first;
    update['idCompany'] = allowedCompanyIds.first;
    update['companyScope'] = 'single';
  }
  return update;
}

Map<String, dynamic> buildPositionSnapshot({
  required Map<String, dynamic> roleData,
  required String fallbackCompanyId,
}) {
  final snapshot = buildRoleSnapshot(
    roleData: roleData,
    fallbackCompanyId: fallbackCompanyId,
  );
  return <String, dynamic>{
    'role_id': snapshot['role_id'],
    'role_name': snapshot['role_name'],
    'role_permissions': snapshot['role_permissions'],
    'role_allowed_company_ids': snapshot['role_allowed_company_ids'],
  };
}

Map<String, dynamic> buildEmployeeRoleAssignmentPatch({
  required Map<String, dynamic> positionData,
  required String fallbackCompanyId,
}) {
  final update = <String, dynamic>{
    'position': (positionData['name'] ?? positionData['position'] ?? '')
        .toString()
        .trim(),
    'position_id': (positionData['id'] ?? positionData['position_id'] ?? '')
        .toString()
        .trim(),
    'role': (positionData['role_name'] ?? positionData['role'] ?? '')
        .toString()
        .trim(),
    'role_name': (positionData['role_name'] ?? positionData['role'] ?? '')
        .toString()
        .trim(),
    'updated_at': FieldValue.serverTimestamp(),
  };
  update.addAll(
    buildPositionSnapshot(
      roleData: positionData,
      fallbackCompanyId: fallbackCompanyId,
    ),
  );
  return update;
}

Future<void> propagateRoleSnapshotToAssignments({
  required FirebaseFirestore firestore,
  required String companyId,
  required String roleId,
  required Map<String, dynamic> roleData,
}) async {
  final normalizedCompanyId = companyId.trim();
  final normalizedRoleId = roleId.trim();
  if (normalizedCompanyId.isEmpty || normalizedRoleId.isEmpty) return;

  final userPatch = buildUserRoleAssignmentPatch(
    roleData: roleData,
    fallbackCompanyId: normalizedCompanyId,
  );
  final employeePatch = buildPositionSnapshot(
    roleData: roleData,
    fallbackCompanyId: normalizedCompanyId,
  );

  final usersSnap = await firestore
      .collection('users')
      .where('idCompany', isEqualTo: normalizedCompanyId)
      .where('role_id', isEqualTo: normalizedRoleId)
      .get();
  final positionsSnap = await firestore
      .collection('roles')
      .where('idCompany', isEqualTo: normalizedCompanyId)
      .where('type', isEqualTo: 'position')
      .where('role_id', isEqualTo: normalizedRoleId)
      .get();
  final employeesSnap = await firestore
      .collection('employees')
      .where('idCompany', isEqualTo: normalizedCompanyId)
      .where('role_id', isEqualTo: normalizedRoleId)
      .get();

  final batch = firestore.batch();
  final userIds = <String>{};

  for (final doc in usersSnap.docs) {
    userIds.add(doc.id);
    batch.update(doc.reference, userPatch);
  }
  for (final doc in positionsSnap.docs) {
    batch.update(doc.reference, {
      ...employeePatch,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
  for (final doc in employeesSnap.docs) {
    batch.update(doc.reference, {
      ...employeePatch,
      'role': (employeePatch['role_name'] ?? '').toString(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
  if (usersSnap.docs.isNotEmpty ||
      positionsSnap.docs.isNotEmpty ||
      employeesSnap.docs.isNotEmpty) {
    await batch.commit();
  }

  final allowedCompanyIds = (userPatch['companyIds'] as List?)
          ?.map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList() ??
      const <String>[];
  if (allowedCompanyIds.isNotEmpty && userIds.isNotEmpty) {
    for (final cid in allowedCompanyIds) {
      await firestore.collection('companies').doc(cid).update({
        'members': FieldValue.arrayUnion(userIds.toList()),
      });
    }
  }
}
