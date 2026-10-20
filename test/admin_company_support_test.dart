import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/admin_company_support.dart';

void main() {
  test('companyAdminIdFromData reads company id aliases', () {
    expect(
      companyAdminIdFromData('profileDoc', {'id_company': 'realCompany'}),
      'realCompany',
    );
  });

  test('companyAdminDisplayName prefers real profile name over placeholder',
      () {
    expect(
      companyAdminDisplayName({
        'name': 'Компания',
        'nameCompany': 'UDI Kazakhstan',
      }),
      'UDI Kazakhstan',
    );
  });

  test('companyAdminDisplayName keeps non-placeholder company name', () {
    expect(
      companyAdminDisplayName({
        'name': 'Forte Test',
      }),
      'Forte Test',
    );
  });

  test('companyAdminDisplayName ignores placeholder aliases', () {
    expect(
      companyAdminDisplayName({
        'nameCompany': 'Компания',
        'company_name': 'Компания',
        'name': 'UDI Kazakhstan',
      }),
      'UDI Kazakhstan',
    );
  });

  test('companyAdminDisplayName reads company_name alias', () {
    expect(
      companyAdminDisplayName({
        'name': 'Компания',
        'company_name': 'UDI Kazakhstan',
      }),
      'UDI Kazakhstan',
    );
  });

  test('companyAdminDisplayName falls back when no name exists', () {
    expect(companyAdminDisplayName({}), 'Без названия');
  });
}
