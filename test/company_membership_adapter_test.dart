import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/company_membership_adapter.dart';

void main() {
  group('CompanyMembershipAdapter', () {
    test('builds selected and allowed memberships from user snapshot', () {
      final adapter = CompanyMembershipAdapter.fromUserData({
        'idCompany': 'c1',
        'activeCompanyId': 'c2',
        'companyIds': ['c1', 'c2', 'c3'],
        'role_allowed_company_ids': ['c2', 'c3'],
        'role': 'cashier',
        'role_id': 'r1',
        'role_name': 'Кассир',
        'role_permissions': ['sales.cash'],
        'tariff_permissions': ['sales.cash', 'sales.view'],
      });

      expect(adapter.selectedCompanyId, 'c2');
      expect(adapter.effectiveAllowedCompanyIds, {'c2', 'c3'});
      expect(adapter.membershipFor('c2')?.isSelected, isTrue);
      expect(adapter.membershipFor('c1')?.isAllowed, isFalse);
      expect(adapter.membershipFor('c3')?.roleName, 'Кассир');
    });

    test('falls back to all company ids when allowed list is empty', () {
      final adapter = CompanyMembershipAdapter.fromUserData({
        'idCompany': 'c1',
        'companyIds': ['c1', 'c9'],
      });

      expect(adapter.selectedCompanyId, 'c1');
      expect(adapter.effectiveAllowedCompanyIds, {'c1', 'c9'});
      expect(adapter.membershipFor('c9'), isNotNull);
    });
  });
}
