import 'package:cloud_firestore/cloud_firestore.dart';

class DefaultCompanyRoleTemplate {
  final String name;
  final String description;
  final List<String> permissions;

  const DefaultCompanyRoleTemplate({
    required this.name,
    required this.description,
    this.permissions = const <String>[],
  });
}

String _normalizedRoleName(String value) => value.trim().toLowerCase();

const String _buyerCategoryRoleName = 'Закупщик / Категорийный менеджер';

String _defaultRoleDocId(String companyId, String roleName) =>
    'default_role__${Uri.encodeComponent(companyId.trim())}__'
    '${Uri.encodeComponent(_normalizedRoleName(roleName))}';

const List<String> _allOwnerPermissions = <String>[
  'scheta.manage',
  'scheta.view',
  'scheta.add',
  'scheta.edit',
  'scheta.deactivate',
  'scheta.delete',
  'scheta.withdrawal',
  'scheta.blocks.total',
  'scheta.blocks.bank',
  'scheta.blocks.cash',
  'scheta.blocks.owner',
  'scheta.blocks.list',
  'scheta.blocks.transactions',
  'scheta.blocks.filters',
  'uchet.view',
  'uchet.blocks.summary',
  'uchet.blocks.compare',
  'uchet.blocks.chart',
  'uchet.blocks.insights',
  'tranzaction.view',
  'tranzaction.add',
  'tranzaction.edit',
  'tranzaction.delete',
  'tranzaction.filter',
  'tranzaction.export',
  'money.obligations',
  'money.expense_categories',
  'funding_requests.view',
  'funding_requests.create',
  'funding_requests.responsible_sign',
  'funding_requests.approve',
  'funding_requests.final_approve',
  'funding_requests.pay',
  'money.view',
  'money.company',
  'money.company_expenses',
  'warehouse.view',
  'warehouse.add',
  'warehouse.move',
  'warehouse.blocks.list',
  'warehouse.blocks.movements',
  'warehouse.blocks.totals',
  'nomenclature.view',
  'nomenclature.add',
  'nomenclature.edit',
  'nomenclature.delete',
  'nomenclature.blocks.list',
  'nomenclature.blocks.filters',
  'services.view',
  'services.add',
  'services.edit',
  'services.delete',
  'suppliers.view',
  'suppliers.add',
  'suppliers.edit',
  'suppliers.delete',
  'sales.view',
  'sales.shops',
  'sales.cashiers',
  'sales.clients',
  'sales.controls',
  'sales.cash',
  'sales.reports',
  'sales.add',
  'sales.edit',
  'sales.delete',
  'sales.income',
  'sales.expenses',
  'sales.profit.shop',
  'sales.profit.cashier',
  'sales.abc',
  'analytics.view',
  'analytics.sales',
  'analytics.fin',
  'analytics.margin',
  'analytics.invest',
  'analytics.models',
  'analytics.abc',
  'analytics.portfolio',
  'audit.view',
  'company.org',
  'company.hr',
  'company.users',
  'company.roles',
  'security.view',
  'security.block',
  'security.restore',
  'security.delete',
  'money.my',
  'money.my_expenses',
  'settings.view',
  'settings.currency',
  'settings.taxes',
  'settings.calculator',
  'settings.rekviziti',
  'settings.roles',
  'settings.users',
  'settings.tariffs',
];

const List<DefaultCompanyRoleTemplate> kDefaultCompanyRoleTemplates = [
  DefaultCompanyRoleTemplate(
    name: 'Владелец / Директор',
    description: 'Полный доступ ко всем блокам компании и настройкам.',
    permissions: _allOwnerPermissions,
  ),
  DefaultCompanyRoleTemplate(
    name: 'Главный бухгалтер',
    description:
        'Финансовый контур, счета, транзакции, расходы, долги и отчеты.',
    permissions: <String>[
      'scheta.manage',
      'scheta.view',
      'scheta.add',
      'scheta.edit',
      'scheta.deactivate',
      'scheta.blocks.total',
      'scheta.blocks.bank',
      'scheta.blocks.cash',
      'scheta.blocks.list',
      'scheta.blocks.transactions',
      'scheta.blocks.filters',
      'tranzaction.view',
      'tranzaction.add',
      'tranzaction.edit',
      'tranzaction.delete',
      'tranzaction.filter',
      'tranzaction.export',
      'uchet.view',
      'uchet.blocks.summary',
      'uchet.blocks.compare',
      'uchet.blocks.chart',
      'uchet.blocks.insights',
      'money.view',
      'money.company',
      'money.company_expenses',
      'money.obligations',
      'money.expense_categories',
      'funding_requests.view',
      'funding_requests.create',
      'funding_requests.responsible_sign',
      'funding_requests.approve',
      'funding_requests.final_approve',
      'funding_requests.pay',
      'warehouse.view',
      'nomenclature.view',
      'analytics.view',
      'analytics.fin',
      'analytics.margin',
      'analytics.invest',
      'analytics.models',
      'audit.view',
      'settings.view',
      'settings.taxes',
      'settings.rekviziti',
    ],
  ),
  DefaultCompanyRoleTemplate(
    name: 'Бухгалтер',
    description: 'Операционный финансовый учет без удаления и экспорта.',
    permissions: <String>[
      'scheta.view',
      'scheta.blocks.bank',
      'scheta.blocks.cash',
      'scheta.blocks.list',
      'scheta.blocks.transactions',
      'tranzaction.view',
      'tranzaction.add',
      'tranzaction.edit',
      'tranzaction.filter',
      'uchet.view',
      'uchet.blocks.summary',
      'money.view',
      'money.company',
      'money.company_expenses',
      'money.obligations',
      'money.expense_categories',
      'funding_requests.view',
      'funding_requests.create',
      'funding_requests.responsible_sign',
      'funding_requests.pay',
      'warehouse.view',
      'warehouse.move',
      'nomenclature.view',
      'analytics.view',
      'analytics.fin',
      'audit.view',
    ],
  ),
  DefaultCompanyRoleTemplate(
    name: 'Кассир',
    description: 'Своя касса, смена, прием оплат и кассовые операции.',
    permissions: <String>[
      'scheta.view',
      'scheta.blocks.cash',
      'tranzaction.view',
      'tranzaction.add',
      'tranzaction.filter',
      'sales.view',
      'sales.cash',
      'audit.view',
    ],
  ),
  DefaultCompanyRoleTemplate(
    name: 'Кладовщик',
    description: 'Физическое движение товара, склады и остатки.',
    permissions: <String>[
      'warehouse.view',
      'warehouse.add',
      'warehouse.move',
      'warehouse.blocks.list',
      'warehouse.blocks.movements',
      'warehouse.blocks.totals',
      'nomenclature.view',
      'nomenclature.blocks.list',
      'nomenclature.blocks.filters',
      'suppliers.view',
    ],
  ),
  DefaultCompanyRoleTemplate(
    name: 'Продавец / Менеджер по продажам',
    description: 'Продажи, клиенты, услуги и просмотр остатков.',
    permissions: <String>[
      'nomenclature.view',
      'nomenclature.blocks.list',
      'services.view',
      'sales.view',
      'sales.shops',
      'sales.clients',
      'sales.add',
      'sales.edit',
      'money.obligations',
      'funding_requests.view',
      'funding_requests.create',
    ],
  ),
  DefaultCompanyRoleTemplate(
    name: 'Аналитик / Финансовый директор',
    description: 'Только чтение агрегированной аналитики и отчетов.',
    permissions: <String>[
      'sales.reports',
      'analytics.view',
      'analytics.abc',
      'analytics.fin',
      'analytics.invest',
      'analytics.margin',
      'analytics.models',
      'analytics.portfolio',
      'analytics.sales',
    ],
  ),
  DefaultCompanyRoleTemplate(
    name: 'HR / Оргструктура',
    description: 'Сотрудники, штатное расписание и оргструктура.',
    permissions: <String>[
      'company.hr',
      'company.org',
    ],
  ),
  DefaultCompanyRoleTemplate(
    name: 'Администратор безопасности',
    description: 'Роли, права доступа, блокировка и восстановление доступа.',
    permissions: <String>[
      'settings.view',
      'settings.roles',
      'settings.users',
      'company.users',
      'company.roles',
      'security.view',
      'security.block',
      'security.restore',
      'security.delete',
    ],
  ),
  DefaultCompanyRoleTemplate(
    name: _buyerCategoryRoleName,
    description:
        'Закупки, категорийное управление, поставщики, цены закупки и кредиторка.',
    permissions: <String>[
      'warehouse.view',
      'warehouse.add',
      'warehouse.move',
      'warehouse.blocks.list',
      'warehouse.blocks.movements',
      'warehouse.blocks.totals',
      'nomenclature.view',
      'nomenclature.add',
      'nomenclature.edit',
      'nomenclature.blocks.list',
      'nomenclature.blocks.filters',
      'suppliers.view',
      'suppliers.add',
      'suppliers.edit',
      'money.obligations',
      'money.company_expenses',
      'funding_requests.view',
      'funding_requests.create',
      'analytics.view',
      'analytics.abc',
      'analytics.portfolio',
    ],
  ),
  DefaultCompanyRoleTemplate(
    name: 'Директор магазина',
    description: 'Операционное управление одной торговой точкой.',
    permissions: <String>[
      'warehouse.view',
      'warehouse.move',
      'warehouse.blocks.list',
      'warehouse.blocks.movements',
      'warehouse.blocks.totals',
      'nomenclature.view',
      'nomenclature.blocks.list',
      'sales.view',
      'sales.shops',
      'sales.cashiers',
      'sales.cash',
      'sales.reports',
      'sales.profit.shop',
      'money.obligations',
      'money.expense_categories',
      'funding_requests.view',
      'funding_requests.create',
      'funding_requests.responsible_sign',
      'analytics.view',
      'analytics.sales',
      'company.hr',
    ],
  ),
];

Future<int> ensureDefaultCompanyRoles({
  required FirebaseFirestore firestore,
  required String companyId,
  required String userId,
  bool seedOnlyWhenNoRoles = true,
}) async {
  final normalizedCompanyId = companyId.trim();
  if (normalizedCompanyId.isEmpty) return 0;

  final rolesSnap = await firestore
      .collection('roles')
      .where('idCompany', isEqualTo: normalizedCompanyId)
      .get();

  final hasAnyRole = rolesSnap.docs.any((doc) {
    final data = doc.data();
    final type = (data['type'] ?? 'role').toString().trim().toLowerCase();
    return type == 'role';
  });
  if (seedOnlyWhenNoRoles && hasAnyRole) {
    return 0;
  }

  final dynamicTemplates =
      await _loadDefaultTemplatesFromAdminCollection(firestore);
  final sourceTemplates = dynamicTemplates.isNotEmpty
      ? dynamicTemplates
      : kDefaultCompanyRoleTemplates;
  final templatesByName = <String, DefaultCompanyRoleTemplate>{};
  for (final template in sourceTemplates) {
    final key = _normalizedRoleName(template.name);
    if (key.isEmpty) continue;
    templatesByName.putIfAbsent(key, () => template);
  }
  final templates = templatesByName.values.toList(growable: false);

  final existingRoleNames = <String>{};
  final existingRoleDocIds = <String>{};
  for (final doc in rolesSnap.docs) {
    existingRoleDocIds.add(doc.id);
    final data = doc.data();
    final type = (data['type'] ?? 'role').toString().trim().toLowerCase();
    if (type != 'role') continue;
    final name = _normalizedRoleName((data['name'] ?? '').toString());
    final source = (data['source'] ?? '').toString().trim();
    if (name == 'закупщик' && source == 'default_company_roles') {
      await doc.reference.set({
        'name': _buyerCategoryRoleName,
        'description':
            'Закупки, категорийное управление, поставщики, цены закупки и кредиторка.',
        'name_key': _normalizedRoleName(_buyerCategoryRoleName),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    if (name.isNotEmpty) {
      existingRoleNames.add(name);
      if (name == 'закупщик') {
        existingRoleNames.add(_normalizedRoleName(_buyerCategoryRoleName));
      }
    }
    final template = templatesByName[name];
    if (template != null) {
      final existingPermissionsRaw = data['permissions'];
      final existingPermissions =
          (existingPermissionsRaw is List ? existingPermissionsRaw : const [])
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toSet();
      final mergedPermissions = {
        ...existingPermissions,
        ...template.permissions,
      }.toList()
        ..sort();
      if (mergedPermissions.length != existingPermissions.length) {
        await doc.reference.set({
          'permissions': mergedPermissions,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  var added = 0;
  for (final template in templates) {
    final roleNameKey = _normalizedRoleName(template.name);
    final defaultDocId = _defaultRoleDocId(normalizedCompanyId, template.name);
    if (roleNameKey.isEmpty ||
        existingRoleNames.contains(roleNameKey) ||
        existingRoleDocIds.contains(defaultDocId)) {
      continue;
    }
    await firestore.collection('roles').doc(defaultDocId).set({
      'type': 'role',
      'name': template.name,
      'description': template.description,
      'permissions': template.permissions,
      'allowed_company_ids': [normalizedCompanyId],
      'idCompany': normalizedCompanyId,
      'user_id': userId,
      'name_key': roleNameKey,
      'source': 'default_company_roles',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    existingRoleNames.add(roleNameKey);
    added++;
  }
  return added;
}

Future<List<DefaultCompanyRoleTemplate>>
    _loadDefaultTemplatesFromAdminCollection(
  FirebaseFirestore firestore,
) async {
  try {
    final snap = await firestore.collection('role_templates').get();
    final templates = <DefaultCompanyRoleTemplate>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final active = data['is_active'];
      if (active is bool && !active) continue;
      final name = (data['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final description = (data['description'] ?? '').toString().trim();
      final permissionsRaw = data['permissions'];
      final permissions = (permissionsRaw is List ? permissionsRaw : const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      templates.add(
        DefaultCompanyRoleTemplate(
          name: name,
          description: description,
          permissions: permissions,
        ),
      );
    }
    templates.sort((a, b) => a.name.compareTo(b.name));
    return templates;
  } catch (_) {
    return const <DefaultCompanyRoleTemplate>[];
  }
}
