import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/default_company_roles.dart';
import 'package:uchet_s_d/utils/permission_catalog.dart';

void main() {
  group('kDefaultCompanyRoleTemplates', () {
    test('contains expected minimum roles list', () {
      expect(kDefaultCompanyRoleTemplates.length, 11);
    });

    test('contains key business roles', () {
      final names = kDefaultCompanyRoleTemplates.map((e) => e.name).toSet();
      expect(names.contains('Владелец / Директор'), isTrue);
      expect(names.contains('Главный бухгалтер'), isTrue);
      expect(names.contains('Бухгалтер'), isTrue);
      expect(names.contains('Кассир'), isTrue);
      expect(names.contains('Кладовщик'), isTrue);
      expect(names.contains('Продавец / Менеджер по продажам'), isTrue);
      expect(names.contains('Аналитик / Финансовый директор'), isTrue);
      expect(names.contains('HR / Оргструктура'), isTrue);
      expect(names.contains('Администратор безопасности'), isTrue);
      expect(names.contains('Закупщик / Категорийный менеджер'), isTrue);
      expect(names.contains('Директор магазина'), isTrue);
    });

    test('role names are unique and non-empty', () {
      final normalized = kDefaultCompanyRoleTemplates
          .map((e) => e.name.trim().toLowerCase())
          .toList();
      final unique = normalized.toSet();

      expect(normalized.any((e) => e.isEmpty), isFalse);
      expect(unique.length, normalized.length);
    });

    test('descriptions are non-empty', () {
      final hasEmptyDescription =
          kDefaultCompanyRoleTemplates.any((e) => e.description.trim().isEmpty);
      expect(hasEmptyDescription, isFalse);
    });

    test('audit access is assigned to accounting audit roles', () {
      final byName = {
        for (final role in kDefaultCompanyRoleTemplates) role.name: role,
      };
      for (final roleName in [
        'Владелец / Директор',
        'Главный бухгалтер',
        'Бухгалтер',
        'Кассир',
      ]) {
        expect(
          byName[roleName]?.permissions.contains('audit.view'),
          isTrue,
          reason: '$roleName должен видеть аудит по ТЗ',
        );
      }
    });

    test('all role permissions exist in permission catalog', () {
      final unknown = <String>{};
      for (final role in kDefaultCompanyRoleTemplates) {
        for (final permission in role.permissions) {
          if (!kPermissionByKey.containsKey(permission)) {
            unknown.add('${role.name}: $permission');
          }
        }
      }

      expect(unknown, isEmpty);
    });
  });
}
