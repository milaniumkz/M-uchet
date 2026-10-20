class CompanyMembershipSnapshot {
  const CompanyMembershipSnapshot({
    required this.companyId,
    required this.isSelected,
    required this.isAllowed,
    required this.role,
    required this.roleId,
    required this.roleName,
    required this.rolePermissions,
    required this.tariffPermissions,
  });

  final String companyId;
  final bool isSelected;
  final bool isAllowed;
  final String role;
  final String roleId;
  final String roleName;
  final Set<String> rolePermissions;
  final Set<String> tariffPermissions;
}

class CompanyMembershipAdapter {
  CompanyMembershipAdapter._({
    required this.primaryCompanyId,
    required this.activeCompanyId,
    required this.companyScope,
    required this.companyIds,
    required this.allowedCompanyIds,
    required this.rolePermissions,
    required this.tariffPermissions,
    required this.memberships,
  });

  factory CompanyMembershipAdapter.fromUserData(Map<String, dynamic>? rawData) {
    final data = rawData ?? const <String, dynamic>{};
    final primaryCompanyId = _normalizeCompanyId(data['idCompany']);
    final activeCompanyId = _normalizeCompanyId(data['activeCompanyId']);
    final companyScope = (data['companyScope'] ?? data['company_scope'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final companyIds = _normalizedStringSet(
      data['companyIds'],
      fallbackSingle: primaryCompanyId,
      extraValues: [activeCompanyId],
    );
    final allowedCompanyIds = _normalizedStringSet(
      data['role_allowed_company_ids'] ??
          data['roleAllowedCompanyIds'] ??
          data['role_companies'],
    );
    final rolePermissions = _normalizedStringSet(
      data['role_permissions'] ?? data['rolePerms'],
    );
    final tariffPermissions = _normalizedStringSet(
      data['tariff_permissions'] ?? data['tariffPerms'],
    );

    final selectedCompanyId = activeCompanyId.isNotEmpty
        ? activeCompanyId
        : (primaryCompanyId.isNotEmpty
            ? primaryCompanyId
            : (allowedCompanyIds.isNotEmpty
                ? (allowedCompanyIds.toList()..sort()).first
                : (companyIds.isNotEmpty
                    ? (companyIds.toList()..sort()).first
                    : '')));
    final unionCompanyIds = <String>{
      ...companyIds,
      ...allowedCompanyIds,
      if (selectedCompanyId.isNotEmpty) selectedCompanyId,
    }.toList()
      ..sort();

    final role = (data['role'] ?? '').toString().trim();
    final roleId = (data['role_id'] ?? '').toString().trim();
    final roleName = (data['role_name'] ?? role).toString().trim();
    final memberships = <String, CompanyMembershipSnapshot>{};
    for (final companyId in unionCompanyIds) {
      memberships[companyId] = CompanyMembershipSnapshot(
        companyId: companyId,
        isSelected: companyId == selectedCompanyId,
        isAllowed:
            allowedCompanyIds.isEmpty || allowedCompanyIds.contains(companyId),
        role: role,
        roleId: roleId,
        roleName: roleName,
        rolePermissions: rolePermissions,
        tariffPermissions: tariffPermissions,
      );
    }

    return CompanyMembershipAdapter._(
      primaryCompanyId: primaryCompanyId,
      activeCompanyId: activeCompanyId,
      companyScope: companyScope,
      companyIds: companyIds,
      allowedCompanyIds: allowedCompanyIds,
      rolePermissions: rolePermissions,
      tariffPermissions: tariffPermissions,
      memberships: memberships,
    );
  }

  final String primaryCompanyId;
  final String activeCompanyId;
  final String companyScope;
  final Set<String> companyIds;
  final Set<String> allowedCompanyIds;
  final Set<String> rolePermissions;
  final Set<String> tariffPermissions;
  final Map<String, CompanyMembershipSnapshot> memberships;

  static Set<String> _normalizedStringSet(
    dynamic raw, {
    String? fallbackSingle,
    List<String> extraValues = const [],
  }) {
    final values = <String>{};
    if (raw is List) {
      for (final item in raw) {
        final value = item.toString().trim();
        if (value.isNotEmpty && value != '__all__') {
          values.add(value);
        }
      }
    }
    final fallback = _normalizeCompanyId(fallbackSingle);
    if (fallback.isNotEmpty) {
      values.add(fallback);
    }
    for (final item in extraValues) {
      final value = _normalizeCompanyId(item);
      if (value.isNotEmpty) {
        values.add(value);
      }
    }
    return values;
  }

  static String _normalizeCompanyId(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    return value == '__all__' ? '' : value;
  }

  String get selectedCompanyId {
    final explicit = memberships.values.where((m) => m.isSelected);
    if (explicit.isNotEmpty) {
      return explicit.first.companyId;
    }
    if (activeCompanyId.isNotEmpty) return activeCompanyId;
    if (primaryCompanyId.isNotEmpty) {
      return primaryCompanyId;
    }
    final sortedAllowed = allowedCompanyIds.toList()..sort();
    if (sortedAllowed.isNotEmpty) return sortedAllowed.first;
    final sortedCompanies = companyIds.toList()..sort();
    if (sortedCompanies.isNotEmpty) return sortedCompanies.first;
    return '';
  }

  Set<String> get effectiveAllowedCompanyIds {
    if (allowedCompanyIds.isEmpty) return companyIds;
    if (companyIds.isEmpty) return allowedCompanyIds;
    return companyIds.intersection(allowedCompanyIds);
  }

  CompanyMembershipSnapshot? membershipFor(String companyId) {
    final trimmed = companyId.trim();
    if (trimmed.isEmpty) return null;
    return memberships[trimmed];
  }
}
