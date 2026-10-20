import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/role_assignment_support.dart';

void main() {
  group('role assignment support', () {
    test('builds stable role snapshot with fallback company', () {
      final snapshot = buildRoleSnapshot(
        roleData: {
          'id': 'r1',
          'name': 'Бухгалтер',
          'permissions': ['a', 'b', 'a'],
          'allowed_company_ids': ['c2'],
        },
        fallbackCompanyId: 'c1',
      );

      expect(snapshot['role_id'], 'r1');
      expect(snapshot['role_name'], 'Бухгалтер');
      expect(snapshot['role_permissions'], ['a', 'b']);
      expect(snapshot['role_allowed_company_ids'], ['c1', 'c2']);
    });

    test('builds user assignment patch with company context', () {
      final patch = buildUserRoleAssignmentPatch(
        roleData: {
          'id': 'r2',
          'name': 'Кассир',
          'permissions': ['sales.cash'],
          'allowed_company_ids': ['c9'],
        },
        fallbackCompanyId: 'c3',
      );

      expect(patch['role_id'], 'r2');
      expect(patch['activeCompanyId'], 'c3');
      expect(patch['idCompany'], 'c3');
      expect(patch['companyIds'], ['c3', 'c9']);
      expect(patch['companyScope'], 'single');
    });

    test('builds employee assignment from position snapshot', () {
      final patch = buildEmployeeRoleAssignmentPatch(
        positionData: {
          'id': 'p1',
          'name': 'Старший кассир',
          'role_id': 'r3',
          'role_name': 'Кассир',
          'role_permissions': ['sales.cash'],
          'role_allowed_company_ids': ['c7'],
        },
        fallbackCompanyId: 'c7',
      );

      expect(patch['position'], 'Старший кассир');
      expect(patch['position_id'], 'p1');
      expect(patch['role_id'], 'r3');
      expect(patch['role_name'], 'Кассир');
      expect(patch['role_permissions'], ['sales.cash']);
    });
  });
}
