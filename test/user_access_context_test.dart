import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/onboarding_progress.dart';
import 'package:uchet_s_d/utils/user_access_context.dart';

void main() {
  group('UserAccessContext company resolution', () {
    test('prefers active company over primary and companyIds', () {
      final context = UserAccessContext.fromData({
        'idCompany': 'c1',
        'activeCompanyId': 'c2',
        'companyIds': ['c1', 'c2', 'c3'],
      });

      expect(context.selectedCompanyId, 'c2');
      expect(context.queryCompanyIds(), ['c2']);
    });

    test('uses all-scope intersection with allowed companies', () {
      final context = UserAccessContext.fromData({
        'idCompany': 'c1',
        'activeCompanyId': 'c1',
        'companyScope': 'all',
        'companyIds': ['c1', 'c2', 'c3'],
        'role_allowed_company_ids': ['c2', 'c3', 'c4'],
      });

      expect(context.queryCompanyIds(), ['c2', 'c3']);
      expect(context.canAccessCompany('c2'), isTrue);
      expect(context.canAccessCompany('c1'), isFalse);
    });
  });

  group('UserAccessContext permissions', () {
    test('admin bypasses permission matrix', () {
      final context = UserAccessContext.fromData({
        'role': 'owner',
      });

      expect(context.hasPermission('analytics.fin'), isTrue);
    });

    test('non-admin requires role and tariff intersection', () {
      final context = UserAccessContext.fromData({
        'role': 'cashier',
        'idCompany': 'c1',
        'activeCompanyId': 'c1',
        'role_permissions': ['sales.cash', 'analytics.fin'],
        'tariff_permissions': ['sales.cash'],
      });

      expect(context.hasPermission('sales.cash'), isTrue);
      expect(context.hasPermission('analytics.fin'), isFalse);
    });
  });

  group('OnboardingProgress mergedStepState', () {
    test('treats saved, skipped and actual counts as done signals', () {
      final state = OnboardingProgress.mergedStepState(
        savedSteps: const {'companies': true},
        skippedSteps: const {'roles': true},
        counts: const {
          'companies': 0,
          'roles': 0,
          'org': 0,
          'employees': 2,
          'accounts': 1,
          'warehouses': 0,
          'shops': 0,
          'products': 0,
          'budgets': 0,
        },
      );

      expect(state['companies'], isTrue);
      expect(state['roles'], isTrue);
      expect(state['employees'], isTrue);
      expect(state['accounts'], isTrue);
      expect(state['shops'], isFalse);
    });
  });
}
