enum LedgerScope {
  management,
  accounting,
  both,
}

enum WarehouseType {
  official,
  unofficial,
}

const Set<String> _officialWarehouseLabels = {
  'official',
  'offical',
  'официальный',
  'официальные товары',
  'white',
  'белый',
  'белый склад',
};

const Set<String> _unofficialWarehouseLabels = {
  'unofficial',
  'неофициальный',
  'неофициальные товары',
  'grey',
  'gray',
  'серый',
  'серый склад',
};

extension LedgerScopeX on LedgerScope {
  String get storageValue {
    switch (this) {
      case LedgerScope.management:
        return 'MANAGEMENT';
      case LedgerScope.accounting:
        return 'ACCOUNTING';
      case LedgerScope.both:
        return 'BOTH';
    }
  }

  String get legacyTypeUchet {
    switch (this) {
      case LedgerScope.management:
        return 'Up1';
      case LedgerScope.accounting:
        return 'Bu';
      case LedgerScope.both:
        return 'Up';
    }
  }

  bool matches(LedgerScope other) {
    if (this == LedgerScope.both || other == LedgerScope.both) {
      return true;
    }
    return this == other;
  }

  String get shortLabel {
    switch (this) {
      case LedgerScope.management:
        return 'С';
      case LedgerScope.accounting:
        return 'Б';
      case LedgerScope.both:
        return 'О';
    }
  }
}

extension WarehouseTypeX on WarehouseType {
  String get storageValue {
    switch (this) {
      case WarehouseType.official:
        return 'OFFICIAL';
      case WarehouseType.unofficial:
        return 'UNOFFICIAL';
    }
  }

  bool get isOfficial => this == WarehouseType.official;

  String get bucketLabel {
    switch (this) {
      case WarehouseType.official:
        return 'Официальные товары';
      case WarehouseType.unofficial:
        return 'Неофициальные товары';
    }
  }
}

LedgerScope ledgerScopeFromLegacyValue(String? raw) {
  final normalized = (raw ?? '').trim().toLowerCase();
  switch (normalized) {
    case 'bu':
    case 'accounting':
      return LedgerScope.accounting;
    case 'up1':
    case 'management':
      return LedgerScope.management;
    case 'up':
    case 'both':
    case 'all':
      return LedgerScope.both;
    default:
      return LedgerScope.accounting;
  }
}

LedgerScope? nullableLedgerScopeFromLegacyValue(String? raw) {
  final normalized = (raw ?? '').trim();
  if (normalized.isEmpty) return null;
  return ledgerScopeFromLegacyValue(normalized);
}

LedgerScope ledgerScopeFromData(
  Map<String, dynamic> data, {
  String field = 'ledger_scope',
}) {
  final explicitRaw = data[field] ?? data['ledgerScope'];
  final explicit = explicitRaw == null ? '' : explicitRaw.toString().trim();
  if (explicit.isNotEmpty && explicit.toLowerCase() != 'null') {
    return ledgerScopeFromLegacyValue(explicit);
  }
  final legacyRaw = data['typeUchet'] ?? data['accounting_mode'];
  return ledgerScopeFromLegacyValue(legacyRaw?.toString());
}

bool ledgerScopeMatchesFilter({
  required String? rawValue,
  required String? rawFilter,
}) {
  final itemScope = ledgerScopeFromLegacyValue(rawValue);
  final filterScope = ledgerScopeFromLegacyValue(rawFilter);
  return filterScope == LedgerScope.both
      ? itemScope == LedgerScope.management ||
          itemScope == LedgerScope.accounting ||
          itemScope == LedgerScope.both
      : itemScope.matches(filterScope);
}

List<String> ledgerScopeSectionKeysForFilter(String? rawFilter) {
  final filterScope = ledgerScopeFromLegacyValue(rawFilter);
  switch (filterScope) {
    case LedgerScope.both:
      return const ['Up', 'Up1', 'Bu'];
    case LedgerScope.management:
      return const ['Up1'];
    case LedgerScope.accounting:
      return const ['Bu'];
  }
}

String ledgerScopeSectionTitle(String? rawFilter) {
  final filterScope = ledgerScopeFromLegacyValue(rawFilter);
  switch (filterScope) {
    case LedgerScope.management:
      return 'Управленческий учет (С)';
    case LedgerScope.accounting:
      return 'Бухгалтерский учет (Б)';
    case LedgerScope.both:
      return 'Общий учет (О)';
  }
}

Map<String, dynamic> ledgerScopeFields({
  required LedgerScope ledgerScope,
  String? legacyTypeUchet,
}) {
  return <String, dynamic>{
    'ledger_scope': ledgerScope.storageValue,
    'ledgerScope': ledgerScope.storageValue,
    'typeUchet': (legacyTypeUchet == null || legacyTypeUchet.trim().isEmpty)
        ? ledgerScope.legacyTypeUchet
        : legacyTypeUchet,
  };
}

String normalizeLegacyTypeUchet(String? raw) {
  return ledgerScopeFromLegacyValue(raw).legacyTypeUchet;
}

bool isAccountingLedgerValue(String? raw) {
  return ledgerScopeFromLegacyValue(raw) == LedgerScope.accounting;
}

bool isManagementLedgerValue(String? raw) {
  return ledgerScopeFromLegacyValue(raw) == LedgerScope.management;
}

String _normalizeWarehouseLabel(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

bool _hasWarehouseToken(String value, Set<String> exactLabels) {
  final normalized = _normalizeWarehouseLabel(value);
  if (normalized.isEmpty) return false;
  if (exactLabels.contains(normalized)) return true;
  final tokens = normalized.split(RegExp(r'[\s\-_]+')).toSet();
  return exactLabels.any((label) {
    final labelTokens = label.split(RegExp(r'[\s\-_]+')).toSet();
    return tokens.containsAll(labelTokens);
  });
}

WarehouseType warehouseTypeFromLegacy({
  String? rawWarehouseType,
  dynamic isOfficial,
  String? warehouse,
  String? parentWarehouse,
}) {
  if (isOfficial is bool) {
    return isOfficial ? WarehouseType.official : WarehouseType.unofficial;
  }

  final explicit = _normalizeWarehouseLabel(rawWarehouseType ?? '');
  if (_officialWarehouseLabels.contains(explicit)) {
    return WarehouseType.official;
  }
  if (_unofficialWarehouseLabels.contains(explicit)) {
    return WarehouseType.unofficial;
  }

  final warehouseLabel = warehouse ?? '';
  final parentLabel = parentWarehouse ?? '';
  if (_hasWarehouseToken(warehouseLabel, _unofficialWarehouseLabels) ||
      _hasWarehouseToken(parentLabel, _unofficialWarehouseLabels)) {
    return WarehouseType.unofficial;
  }
  if (_hasWarehouseToken(warehouseLabel, _officialWarehouseLabels) ||
      _hasWarehouseToken(parentLabel, _officialWarehouseLabels)) {
    return WarehouseType.official;
  }
  return WarehouseType.official;
}

WarehouseType? warehouseTypeFromExplicitValue(
  String? rawWarehouseType, {
  dynamic isOfficial,
}) {
  if (isOfficial is bool) {
    return isOfficial ? WarehouseType.official : WarehouseType.unofficial;
  }

  final explicit = _normalizeWarehouseLabel(rawWarehouseType ?? '');
  if (_officialWarehouseLabels.contains(explicit)) {
    return WarehouseType.official;
  }
  if (_unofficialWarehouseLabels.contains(explicit)) {
    return WarehouseType.unofficial;
  }
  return null;
}

WarehouseType warehouseTypeFromData(Map<String, dynamic> data) {
  final rawWarehouseType = data['warehouseType'] ?? data['warehouse_type'];
  final explicit = warehouseTypeFromExplicitValue(
    rawWarehouseType?.toString(),
    isOfficial: data['isOfficial'] ?? data['is_official'] ?? data['official'],
  );
  if (explicit != null) {
    return explicit;
  }
  return warehouseTypeFromLegacy(
    rawWarehouseType:
        rawWarehouseType?.toString(),
    isOfficial: data['isOfficial'] ?? data['is_official'] ?? data['official'],
    warehouse: (data['warehouse'] ?? data['name'])?.toString(),
    parentWarehouse: (data['parentWarehouse'] ?? data['parent'])?.toString(),
  );
}

Map<String, dynamic> warehouseTypeFields(WarehouseType warehouseType) {
  return <String, dynamic>{
    'warehouseType': warehouseType.storageValue,
    'warehouse_type': warehouseType.storageValue,
    'isOfficial': warehouseType.isOfficial,
    'is_official': warehouseType.isOfficial,
  };
}
