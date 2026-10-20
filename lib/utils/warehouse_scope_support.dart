Set<String> resolveAllowedWarehouseNames({
  required Map<String, dynamic>? userData,
  required List<Map<String, dynamic>> warehouseDocs,
}) {
  final data = userData ?? const <String, dynamic>{};
  final namesRaw = data['warehouseNames'] ?? data['warehouse_names'] ?? [];
  final idsRaw = data['warehouseIds'] ?? data['warehouse_ids'] ?? [];
  final singleRaw = data['warehouseName'] ?? data['warehouse_name'] ?? '';
  final byId = <String, String>{};
  for (final w in warehouseDocs) {
    final id = (w['id'] ?? '').toString().trim();
    final name = (w['name'] ?? '').toString().trim();
    if (id.isNotEmpty && name.isNotEmpty) {
      byId[id] = name;
    }
  }
  final names = <String>{};
  if (singleRaw.toString().trim().isNotEmpty) {
    names.addAll(
      singleRaw
          .toString()
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty),
    );
  }
  if (namesRaw is List) {
    names.addAll(
      namesRaw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty),
    );
  }
  if (idsRaw is List) {
    for (final id in idsRaw.map((e) => e.toString().trim())) {
      final name = byId[id];
      if (name != null && name.isNotEmpty) {
        names.add(name);
      }
    }
  }
  return names;
}

bool isShopScopedRole(Map<String, dynamic>? userData) {
  final role = ((userData ?? const <String, dynamic>{})['role'] ?? '')
      .toString()
      .toLowerCase();
  return role.contains('shop') ||
      role.contains('store') ||
      role.contains('магаз') ||
      role.contains('директор магазина');
}

Set<String> resolveAllowedShopIds(Map<String, dynamic>? userData) {
  final data = userData ?? const <String, dynamic>{};
  final ids = <String>{};
  for (final key in [
    'shopId',
    'shop_id',
    'storeId',
    'store_id',
    'assignedShopId',
    'assigned_shop_id',
  ]) {
    final value = (data[key] ?? '').toString().trim();
    if (value.isNotEmpty) ids.add(value);
  }
  for (final key in [
    'shopIds',
    'shop_ids',
    'storeIds',
    'store_ids',
    'allowedShopIds',
    'allowed_shop_ids',
  ]) {
    final value = data[key];
    if (value is Iterable) {
      ids.addAll(
        value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty),
      );
    }
  }
  return ids;
}

bool isShopAllowedForUser({
  required Map<String, dynamic>? userData,
  required Map<String, dynamic> item,
}) {
  if (!isShopScopedRole(userData)) return true;
  final allowedIds = resolveAllowedShopIds(userData);
  if (allowedIds.isEmpty) return false;
  final itemShopId = (item['shop_id'] ??
          item['shopId'] ??
          item['sales_source_id'] ??
          item['salesSourceId'] ??
          item['id'] ??
          '')
      .toString()
      .trim();
  return itemShopId.isNotEmpty && allowedIds.contains(itemShopId);
}

List<Map<String, dynamic>> filterRowsByUserShopScope({
  required Map<String, dynamic>? userData,
  required List<Map<String, dynamic>> rows,
}) {
  if (!isShopScopedRole(userData)) return rows;
  return rows
      .where((row) => isShopAllowedForUser(userData: userData, item: row))
      .toList();
}

Set<String> resolveSaleIdsFromRows(List<Map<String, dynamic>> rows) {
  final ids = <String>{};
  for (final row in rows) {
    for (final key in ['id', 'sale_id', 'saleId']) {
      final value = (row[key] ?? '').toString().trim();
      if (value.isNotEmpty) ids.add(value);
    }
  }
  return ids;
}

List<Map<String, dynamic>> filterRowsBySaleIds({
  required List<Map<String, dynamic>> rows,
  required Set<String> saleIds,
}) {
  if (saleIds.isEmpty) return const [];
  return rows.where((row) {
    final saleId = (row['sale_id'] ?? row['saleId'] ?? '').toString().trim();
    return saleId.isNotEmpty && saleIds.contains(saleId);
  }).toList();
}

List<Map<String, dynamic>> filterRowsByShopScopeOrSaleIds({
  required Map<String, dynamic>? userData,
  required List<Map<String, dynamic>> rows,
  required Set<String> saleIds,
}) {
  if (!isShopScopedRole(userData)) return rows;
  return rows.where((row) {
    if (isShopAllowedForUser(userData: userData, item: row)) return true;
    final saleId = (row['sale_id'] ?? row['saleId'] ?? '').toString().trim();
    return saleId.isNotEmpty && saleIds.contains(saleId);
  }).toList();
}

List<Map<String, dynamic>> filterIncassationsByUserShopScope({
  required Map<String, dynamic>? userData,
  required List<Map<String, dynamic>> incassations,
  required List<Map<String, dynamic>> cashRegisters,
}) {
  if (!isShopScopedRole(userData)) return incassations;
  final allowedRegisterIds = filterRowsByUserShopScope(
    userData: userData,
    rows: cashRegisters,
  )
      .map((row) => (row['id'] ?? '').toString().trim())
      .where((id) => id.isNotEmpty)
      .toSet();

  return incassations.where((row) {
    if (isShopAllowedForUser(userData: userData, item: row)) return true;
    final shiftId = (row['cash_register_shift_id'] ??
            row['cashRegisterShiftId'] ??
            row['cash_register_id'] ??
            row['cashRegisterId'] ??
            '')
        .toString()
        .trim();
    return shiftId.isNotEmpty && allowedRegisterIds.contains(shiftId);
  }).toList();
}
