import '/utils/company_membership_adapter.dart';

class UserAccessContext {
  UserAccessContext._({
    required this.data,
    required this.membershipAdapter,
    required this.role,
    required this.isAdmin,
    required this.isOwner,
    required this.primaryCompanyId,
    required this.activeCompanyId,
    required this.companyScope,
    required this.companyIds,
    required this.allowedCompanyIds,
    required this.rolePermissions,
    required this.tariffPermissions,
  });

  factory UserAccessContext.fromData(Map<String, dynamic>? rawData) {
    final data = rawData ?? const <String, dynamic>{};
    final membershipAdapter = CompanyMembershipAdapter.fromUserData(data);
    final role = (data['role'] ?? '').toString().trim();
    final isAdmin = membershipAdapter.rolePermissions.isEmpty &&
        _isAdminUserData(data, role);

    return UserAccessContext._(
      data: Map<String, dynamic>.from(data),
      membershipAdapter: membershipAdapter,
      role: role,
      isAdmin: isAdmin,
      isOwner: _isOwnerRole(role),
      primaryCompanyId: membershipAdapter.primaryCompanyId,
      activeCompanyId: membershipAdapter.activeCompanyId,
      companyScope: membershipAdapter.companyScope,
      companyIds: membershipAdapter.companyIds,
      allowedCompanyIds: membershipAdapter.allowedCompanyIds,
      rolePermissions: membershipAdapter.rolePermissions,
      tariffPermissions: membershipAdapter.tariffPermissions,
    );
  }

  final Map<String, dynamic> data;
  final CompanyMembershipAdapter membershipAdapter;
  final String role;
  final bool isAdmin;
  final bool isOwner;
  final String primaryCompanyId;
  final String activeCompanyId;
  final String companyScope;
  final Set<String> companyIds;
  final Set<String> allowedCompanyIds;
  final Set<String> rolePermissions;
  final Set<String> tariffPermissions;

  static bool _isAdminUserData(Map<String, dynamic> data, String role) {
    final normalizedRole = role.toLowerCase();
    return data['is_admin'] == true ||
        data['admin'] == true ||
        normalizedRole == 'admin' ||
        normalizedRole == 'owner' ||
        normalizedRole == 'business_owner' ||
        normalizedRole == 'владелец' ||
        normalizedRole == 'владелец / директор' ||
        normalizedRole == 'super_admin' ||
        normalizedRole == 'superadmin';
  }

  static bool _isOwnerRole(String role) {
    final normalizedRole = role.toLowerCase().trim();
    return normalizedRole == 'owner' ||
        normalizedRole == 'business_owner' ||
        normalizedRole == 'владелец' ||
        normalizedRole == 'владелец / директор';
  }

  String get selectedCompanyId {
    return membershipAdapter.selectedCompanyId;
  }

  Set<String> get effectiveAllowedCompanyIds {
    return membershipAdapter.effectiveAllowedCompanyIds;
  }

  List<String> queryCompanyIds() {
    final selected = selectedCompanyId;
    final allowed = effectiveAllowedCompanyIds;
    if (companyScope == 'all') {
      if (allowed.isNotEmpty) {
        return allowed.toList()..sort();
      }
      if (companyIds.isNotEmpty) {
        return companyIds.toList()..sort();
      }
    }
    if (selected.isNotEmpty) {
      return [selected];
    }
    if (allowed.isNotEmpty) {
      return [allowed.first];
    }
    if (companyIds.isNotEmpty) {
      return [companyIds.first];
    }
    return const [];
  }

  bool canAccessCompany(String companyId) {
    final trimmed = companyId.trim();
    if (trimmed.isEmpty) return false;
    if (isOwner || isAdmin) return true;
    final allowed = effectiveAllowedCompanyIds;
    if (allowed.isNotEmpty) {
      return allowed.contains(trimmed);
    }
    if (companyIds.isNotEmpty) {
      return companyIds.contains(trimmed);
    }
    return selectedCompanyId == trimmed;
  }

  bool hasPermission(String permissionKey) {
    if (permissionKey.trim().isEmpty) return false;
    if (isOwner || isAdmin) return true;

    final selected = selectedCompanyId;
    if (allowedCompanyIds.isNotEmpty &&
        selected.isNotEmpty &&
        !allowedCompanyIds.contains(selected)) {
      return false;
    }

    if (rolePermissions.isEmpty && tariffPermissions.isEmpty) {
      if (isAdmin) return true;
      return false;
    }

    final inRole = rolePermissions.contains(permissionKey);
    if (tariffPermissions.isEmpty) {
      return inRole;
    }
    return inRole && tariffPermissions.contains(permissionKey);
  }

  bool needsOnboarding({
    required String authUid,
    required String userDocUid,
    required bool onboardingComplete,
  }) {
    final auth = authUid.trim();
    final doc = userDocUid.trim();
    if (auth.isEmpty || doc.isEmpty || auth != doc) return false;
    if (!isOwner) return false;
    return !onboardingComplete;
  }

  Map<String, dynamic> companySelectionUpdate({
    required String companyId,
    required bool allCompanies,
  }) {
    final trimmed = companyId.trim();
    if (trimmed.isEmpty) return const <String, dynamic>{};
    return <String, dynamic>{
      'idCompany': trimmed,
      'activeCompanyId': trimmed,
      'companyScope': allCompanies ? 'all' : 'single',
      'companyIds': <String>{
        ...companyIds,
        trimmed,
      }.toList(),
    };
  }
}
