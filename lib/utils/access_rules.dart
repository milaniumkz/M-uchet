import 'user_access_context.dart';

class AccessRules {
  static bool isAdminUserData(Map<String, dynamic> data) {
    return UserAccessContext.fromData(data).isAdmin;
  }

  static bool isOnboardingAllowedPath(
    String path, {
    required Set<String> allowedPaths,
  }) {
    final normalized = path.trim();
    return allowedPaths.contains(normalized);
  }

  static bool isAdminRole(String roleRaw) {
    final role = roleRaw.trim().toLowerCase();
    return role == 'admin' ||
        role == 'owner' ||
        role == 'business_owner' ||
        role == 'владелец' ||
        role == 'владелец / директор' ||
        role == 'super_admin' ||
        role == 'superadmin';
  }

  static bool hasPermission({
    required Map<String, dynamic> data,
    required String permissionKey,
  }) {
    return UserAccessContext.fromData(data).hasPermission(permissionKey);
  }

  static bool needsOnboarding({
    required String authUid,
    required String userDocUid,
    required String role,
    required bool onboardingComplete,
  }) {
    return UserAccessContext.fromData({'role': role}).needsOnboarding(
      authUid: authUid,
      userDocUid: userDocUid,
      onboardingComplete: onboardingComplete,
    );
  }
}
