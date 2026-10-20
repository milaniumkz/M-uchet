import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/effective_company_support.dart';

void main() {
  group('resolveEffectiveCompanyId', () {
    test('prefers selected active company from user snapshot', () {
      final companyId = resolveEffectiveCompanyId(
        userData: {
          'idCompany': '__all__',
          'activeCompanyId': 'c2',
          'companyIds': ['c1', 'c2'],
        },
        fallbackUserId: 'u1',
      );

      expect(companyId, 'c2');
    });

    test('ignores all-companies marker as document id', () {
      final companyId = resolveEffectiveCompanyId(
        userData: {
          'idCompany': '__all__',
          'activeCompanyId': '__all__',
          'companyIds': ['c1', 'c2'],
          'companyScope': 'all',
        },
        fallbackUserId: 'u1',
      );

      expect(companyId, 'c1');
    });

    test('falls back to user uid when snapshot has no company data', () {
      final companyId = resolveEffectiveCompanyId(
        userData: const {},
        fallbackUserId: 'u1',
      );

      expect(companyId, 'u1');
    });
  });
}
