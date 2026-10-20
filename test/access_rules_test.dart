import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/access_rules.dart';

void main() {
  group('AccessRules.isAdminRole', () {
    test('returns true for known admin roles', () {
      expect(AccessRules.isAdminRole('admin'), isTrue);
      expect(AccessRules.isAdminRole('owner'), isTrue);
      expect(AccessRules.isAdminRole('business_owner'), isTrue);
      expect(AccessRules.isAdminRole('владелец'), isTrue);
      expect(AccessRules.isAdminRole('super_admin'), isTrue);
      expect(AccessRules.isAdminRole('superadmin'), isTrue);
    });

    test('returns false for employee roles', () {
      expect(AccessRules.isAdminRole('emp'), isFalse);
      expect(AccessRules.isAdminRole('cashier'), isFalse);
      expect(AccessRules.isAdminRole(''), isFalse);
    });
  });

  group('AccessRules.isAdminUserData', () {
    test('returns true for admin markers and admin roles', () {
      expect(AccessRules.isAdminUserData({'is_admin': true}), isTrue);
      expect(AccessRules.isAdminUserData({'admin': true}), isTrue);
      expect(AccessRules.isAdminUserData({'role': 'owner'}), isTrue);
    });

    test('returns false for non-admin user data', () {
      expect(AccessRules.isAdminUserData({'role': 'cashier'}), isFalse);
      expect(AccessRules.isAdminUserData(const <String, dynamic>{}), isFalse);
    });
  });

  group('AccessRules.hasPermission', () {
    test('grants all permissions for admin flag', () {
      final data = <String, dynamic>{
        'role': 'emp',
        'is_admin': true,
      };
      expect(
        AccessRules.hasPermission(data: data, permissionKey: 'any.key'),
        isTrue,
      );
    });

    test('grants all permissions for legacy admin field', () {
      final data = <String, dynamic>{
        'role': 'emp',
        'admin': true,
      };
      expect(
        AccessRules.hasPermission(data: data, permissionKey: 'money.company'),
        isTrue,
      );
    });

    test('grants all permissions for admin role', () {
      final data = <String, dynamic>{
        'role': 'admin',
      };
      expect(
        AccessRules.hasPermission(data: data, permissionKey: 'sales.cash'),
        isTrue,
      );
    });

    test('denies when no permissions assigned for non-admin', () {
      final data = <String, dynamic>{
        'role': 'emp',
      };
      expect(
        AccessRules.hasPermission(data: data, permissionKey: 'sales.cash'),
        isFalse,
      );
    });

    test('uses role permissions when no tariff restrictions', () {
      final data = <String, dynamic>{
        'role': 'emp',
        'role_permissions': ['sales.cash', 'money.my'],
      };
      expect(
        AccessRules.hasPermission(data: data, permissionKey: 'sales.cash'),
        isTrue,
      );
      expect(
        AccessRules.hasPermission(data: data, permissionKey: 'money.company'),
        isFalse,
      );
    });

    test('requires intersection of role and tariff permissions', () {
      final data = <String, dynamic>{
        'role': 'emp',
        'role_permissions': ['sales.cash', 'money.my'],
        'tariff_permissions': ['sales.cash', 'analytics.fin'],
      };
      expect(
        AccessRules.hasPermission(data: data, permissionKey: 'sales.cash'),
        isTrue,
      );
      expect(
        AccessRules.hasPermission(data: data, permissionKey: 'money.my'),
        isFalse,
      );
    });

    test('reads camelCase fallback fields', () {
      final data = <String, dynamic>{
        'role': 'emp',
        'rolePerms': ['sales.cash'],
        'tariffPerms': ['sales.cash'],
      };
      expect(
        AccessRules.hasPermission(data: data, permissionKey: 'sales.cash'),
        isTrue,
      );
    });

    test('uses role_companies and idCompany fallbacks', () {
      final data = <String, dynamic>{
        'role': 'emp',
        'idCompany': 'c1',
        'role_companies': ['c1'],
        'role_permissions': ['sales.cash'],
      };
      expect(
        AccessRules.hasPermission(data: data, permissionKey: 'sales.cash'),
        isTrue,
      );
    });

    test('ignores malformed company permissions container', () {
      final data = <String, dynamic>{
        'role': 'emp',
        'activeCompanyId': 'c1',
        'role_allowed_company_ids': 'c2',
        'role_permissions': ['sales.cash'],
      };
      expect(
        AccessRules.hasPermission(data: data, permissionKey: 'sales.cash'),
        isTrue,
      );
    });

    test('denies when active company not in allowed list', () {
      final data = <String, dynamic>{
        'role': 'emp',
        'activeCompanyId': 'c2',
        'role_allowed_company_ids': ['c1'],
        'role_permissions': ['sales.cash'],
      };
      expect(
        AccessRules.hasPermission(data: data, permissionKey: 'sales.cash'),
        isFalse,
      );
    });

    test('allows when active company is in allowed list', () {
      final data = <String, dynamic>{
        'role': 'emp',
        'activeCompanyId': 'c1',
        'role_allowed_company_ids': ['c1', 'c2'],
        'role_permissions': ['sales.cash'],
      };
      expect(
        AccessRules.hasPermission(data: data, permissionKey: 'sales.cash'),
        isTrue,
      );
    });
  });

  group('AccessRules.needsOnboarding', () {
    test('owner with same uid and incomplete onboarding requires onboarding',
        () {
      expect(
        AccessRules.needsOnboarding(
          authUid: 'u1',
          userDocUid: 'u1',
          role: 'owner',
          onboardingComplete: false,
        ),
        isTrue,
      );
    });

    test('employee never requires onboarding', () {
      expect(
        AccessRules.needsOnboarding(
          authUid: 'u1',
          userDocUid: 'u1',
          role: 'emp',
          onboardingComplete: false,
        ),
        isFalse,
      );
    });

    test('admin role but not owner does not require onboarding', () {
      expect(
        AccessRules.needsOnboarding(
          authUid: 'u1',
          userDocUid: 'u1',
          role: 'admin',
          onboardingComplete: false,
        ),
        isFalse,
      );
    });

    test('owner with completed onboarding does not require onboarding', () {
      expect(
        AccessRules.needsOnboarding(
          authUid: 'u1',
          userDocUid: 'u1',
          role: 'owner',
          onboardingComplete: true,
        ),
        isFalse,
      );
    });

    test('mismatched uid does not require onboarding', () {
      expect(
        AccessRules.needsOnboarding(
          authUid: 'u1',
          userDocUid: 'u2',
          role: 'owner',
          onboardingComplete: false,
        ),
        isFalse,
      );
    });

    test('empty uid does not require onboarding', () {
      expect(
        AccessRules.needsOnboarding(
          authUid: '',
          userDocUid: 'u1',
          role: 'owner',
          onboardingComplete: false,
        ),
        isFalse,
      );
      expect(
        AccessRules.needsOnboarding(
          authUid: 'u1',
          userDocUid: '',
          role: 'owner',
          onboardingComplete: false,
        ),
        isFalse,
      );
    });
  });

  group('AccessRules.isOnboardingAllowedPath', () {
    const allowed = <String>{
      '/companyOnboarding',
      '/companySetup',
      '/scheta',
      '/sclad',
      '/shop',
      '/tovar',
      '/statRas',
      '/login',
      '/regPage',
    };

    test('returns true for allowed paths', () {
      expect(
        AccessRules.isOnboardingAllowedPath(
          '/companyOnboarding',
          allowedPaths: allowed,
        ),
        isTrue,
      );
      expect(
        AccessRules.isOnboardingAllowedPath('/login', allowedPaths: allowed),
        isTrue,
      );
    });

    test('returns false for forbidden paths', () {
      expect(
        AccessRules.isOnboardingAllowedPath('/home', allowedPaths: allowed),
        isFalse,
      );
      expect(
        AccessRules.isOnboardingAllowedPath('/tranzaction',
            allowedPaths: allowed),
        isFalse,
      );
    });
  });
}
